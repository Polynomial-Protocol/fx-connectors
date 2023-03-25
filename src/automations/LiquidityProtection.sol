// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";
import {ReentrancyGuardUpgradable} from "../libraries/ReentracyUpgradable.sol";

interface IList {
    function accountID(address) external view returns (uint64);
}

interface IPerpMarket {
    function remainingMargin(address account) external view returns (uint256 marginRemaining, bool invalid);
    function notionalValue(address account) external view returns (int256 value, bool invalid);
    function assetPrice() external view returns (uint256 price, bool invalid);
    function liquidationPrice(address) external view returns (uint256 price, bool invalid);
}

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
}

contract LiquidityProtection is Initializable, AuthUpgradable, ReentrancyGuardUpgradable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    function initialize(address _owner) public initializer {
        _auth_init(_owner, Authority(0x19828283852a852f8cFfF4696038Bc19E5070A49));
        _reentrancy_init();
    }

    struct Protection {
        address[] markets;
        bool[] actions; //0 represents close, 1 represents rebalance
        uint256[] thresholds;
        uint256[] priceImpactDeltas;
    }

    mapping(address => Protection) protection;

    function updateProtection(
        address[] memory _markets,
        bool[] memory _actions,
        uint256[] memory _thresholds,
        uint256[] memory _priceImpactDeltas
    ) external nonReentrant {
        require(isAllowed());
        require(_markets.length == _actions.length);
        require(_markets.length == _thresholds.length);
        Protection storage _protection = protection[msg.sender];
        _protection.markets = _markets;
        _protection.actions = _actions;
        _protection.thresholds = _thresholds;
        _protection.priceImpactDeltas = _priceImpactDeltas;
    }

    function _rebalanceMargin(address user, address[] memory markets) internal {
        uint256 totalNotionalSize = 0;
        uint256[] memory notionalValues = new uint256[](markets.length);
        uint256[] memory margins = new uint256[](markets.length);
        uint256 totalMargin = 0;
        for (uint256 i = 0; i < markets.length; i++) {
            (uint256 marginRemaining, bool invalid) = IPerpMarket(markets[i]).remainingMargin(user);
            (int256 _notionalValue, bool invalid2) = (IPerpMarket(markets[i]).notionalValue(user));
            require(!(invalid || invalid2));
            totalNotionalSize += _abs(_notionalValue);

            notionalValues[i] = _abs(_notionalValue);
            margins[i] = marginRemaining;
            totalMargin += marginRemaining;
        }
        //@Todo: Add fees deduction from total margin

        uint256 actionsLength = markets.length;

        string[] memory targets = new string[](actionsLength);
        bytes[] memory datas = new bytes[](actionsLength);

        // first remove margin
        for (uint256 i = 0; i < markets.length; i++) {
            uint256 marginForMarket = notionalValues[i].mulDivDown(totalMargin, totalNotionalSize);

            targets[i] = "Synthetix-Perp-v1.2";
            if (margins[i] >= marginForMarket) {
                datas[i] = abi.encodeWithSignature(
                    "removeMargin(address,uint256,uint256,uint256)", markets[i], margins[i] - marginForMarket, 0, 0
                );
            }
        }
        // add margin
        for (uint256 i = 0; i < markets.length; i++) {
            uint256 marginForMarket = notionalValues[i].mulDivDown(totalMargin, totalNotionalSize);

            targets[i] = "Synthetix-Perp-v1.2";
            if (margins[i] <= marginForMarket) {
                datas[i] = abi.encodeWithSignature(
                    "addMargin(address,uint256,uint256,uint256)", markets[i], marginForMarket - margins[i], 0, 0
                );
            }
        }

        IAccount(user).cast(targets, datas, address(0x0));
    }

    function _closeMarket(address user, address[] memory market, uint256[] memory priceImpactDeltas, uint256 length)
        internal
    {
        string[] memory targetNames = new string[](length);
        bytes[] memory datas = new bytes[](length);
        for (uint256 i = 0; i < length; i++) {
            targetNames[i] = "Synthetix-Perp-v1.2";
            datas[i] = abi.encodeWithSignature("closeTrade(address,uint256)", market[i], priceImpactDeltas[i]);
        }
        IAccount(user).cast(targetNames, datas, address(0x0));
    }

    function execute(address user) external nonReentrant requiresAuth {
        bool canRebalance = false;
        Protection memory _protection = protection[user];
        for (uint256 i = 0; i < _protection.markets.length; i++) {
            (uint256 assetPrice, bool invalid) = IPerpMarket(_protection.markets[i]).assetPrice();
            (uint256 liquidationPrice, bool invalid2) = IPerpMarket(_protection.markets[i]).liquidationPrice(user);
            require(!(invalid || invalid2));

            if (isDanger(liquidationPrice, assetPrice, _protection.thresholds[i]) && _protection.actions[i]) {
                canRebalance = true;
                break;
            }
        }
        if (canRebalance) {
            _rebalanceMargin(user, _protection.markets);
        }
        address[] memory markets = new address[](_protection.markets.length);
        uint256[] memory priceImpactDelta = new uint256[](_protection.markets.length);
        uint256 index = 0;
        for (uint256 i = 0; i < _protection.markets.length; i++) {
            (uint256 assetPrice, bool invalid) = IPerpMarket(_protection.markets[i]).assetPrice();
            (uint256 liquidationPrice, bool invalid2) = IPerpMarket(_protection.markets[i]).liquidationPrice(msg.sender);
            require(!(invalid || invalid2));

            if (isDanger(liquidationPrice, assetPrice, _protection.thresholds[i]) && _protection.actions[i] == false) {
                markets[index] = _protection.markets[i];
                priceImpactDelta[index++] = _protection.priceImpactDeltas[i];
            }
        }
        _closeMarket(user, markets, priceImpactDelta, index);
    }

    /// @notice Returns whether an address is a SCW or not
    function isAllowed() internal view returns (bool) {
        return IList(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B).accountID(msg.sender) != 0;
    }

    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function isDanger(uint256 liqPrice, uint256 curPrice, uint256 threshold) internal pure returns (bool) {
        return _abs(int256(liqPrice) - int256(curPrice)) <= _min(liqPrice, curPrice).mulWadDown(threshold);
    }
}
