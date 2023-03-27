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

    struct Protection {
        address market;
        bool action; //0 represents close, 1 represents rebalance
        uint256 threshold;
        uint256 priceImpactDelta;
    }

    /// -----------------------------------------------------------------------
    /// State Variables
    /// -----------------------------------------------------------------------

    /// @notice Flat fee charged per each order, taken from margin upon execution
    uint256 public flatFee;

    /// @notice Percentage fee charged per each order (or dollar value)
    uint256 public percentageFee;

    /// @notice Fee receipient
    address public feeReceipient;

    mapping(address => Protection[]) protections;
    mapping(address => bool) public allowed;

    function initialize(address _owner, uint256 _flatFee, uint256 _percentageFee) public initializer {
        _auth_init(_owner, Authority(0x19828283852a852f8cFfF4696038Bc19E5070A49));
        _reentrancy_init();
        flatFee = _flatFee;
        percentageFee = _percentageFee;
    }

    modifier onlyAllowed(address user) {
        require(allowed[user], "Not allowed");
        _;
    }

    function updateProtection(Protection[] memory _protection) external nonReentrant {
        require(isAllowed());

        Protection[] storage protection = protections[msg.sender];

        while (protection.length > 0) {
            protection.pop();
        }
        for (uint256 i = 0; i < _protection.length; i++) {
            protection.push(_protection[i]);
        }
    }

    function _rebalanceMargin(address user, Protection[] memory protection) internal {
        uint256 totalNotionalSize = 0;
        uint256[] memory notionalValues = new uint256[](protection.length);
        uint256[] memory margins = new uint256[](protection.length);
        uint256 totalMargin = 0;
        for (uint256 i = 0; i < protection.length; i++) {
            (uint256 marginRemaining, bool invalid) = IPerpMarket(protection[i].market).remainingMargin(user);
            (int256 _notionalValue, bool invalid2) = (IPerpMarket(protection[i].market).notionalValue(user));
            require(!(invalid || invalid2));
            totalNotionalSize += _abs(_notionalValue);

            notionalValues[i] = _abs(_notionalValue);
            margins[i] = marginRemaining;
            totalMargin += marginRemaining;
        }

        uint256 totalFees = flatFee + totalNotionalSize.mulWadDown(percentageFee);
        totalMargin -= totalFees;

        uint256 actionsLength = protection.length;

        string[] memory targets = new string[](actionsLength + 1);
        bytes[] memory datas = new bytes[](actionsLength + 1);

        // first remove margin
        uint256 index = 0;
        for (uint256 i = 0; i < protection.length; i++) {
            uint256 marginForMarket = notionalValues[i].mulDivDown(totalMargin, totalNotionalSize);

            targets[i] = "Synthetix-Perp-v1.2";
            if (margins[i] >= marginForMarket) {
                datas[index++] = abi.encodeWithSignature(
                    "removeMargin(address,uint256,uint256,uint256)",
                    protection[i].market,
                    margins[i] - marginForMarket,
                    0,
                    0
                );
            }
        }
        // add margin
        for (uint256 i = 0; i < protection.length; i++) {
            uint256 marginForMarket = notionalValues[i].mulDivDown(totalMargin, totalNotionalSize);

            targets[i] = "Synthetix-Perp-v1.2";
            if (margins[i] < marginForMarket) {
                datas[index++] = abi.encodeWithSignature(
                    "addMargin(address,uint256,uint256,uint256)",
                    protection[i].market,
                    marginForMarket - margins[i],
                    0,
                    0
                );
            }
        }
        targets[index] = "Basic-v1";
        datas[index] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9,
            totalFees,
            feeReceipient,
            0,
            0
        );

        IAccount(user).cast(targets, datas, address(0x0));
    }

    function _closeMarket(address user, Protection[] memory markets, uint256 length) internal {
        string[] memory targetNames = new string[](length);
        bytes[] memory datas = new bytes[](length);
        for (uint256 i = 0; i < length; i++) {
            targetNames[i] = "Synthetix-Perp-v1.2";
            datas[i] =
                abi.encodeWithSignature("closeTrade(address,uint256)", markets[i].market, markets[i].priceImpactDelta);
        }
        IAccount(user).cast(targetNames, datas, address(0x0));
    }

    // Only closes the markets that are in danger
    function executeV1(address user) external nonReentrant requiresAuth onlyAllowed(user) {
        Protection[] memory _protection = protections[user];
        Protection[] memory marketsToClose = new Protection[](_protection.length);
        uint256 length = 0;
        for (uint256 i = 0; i < _protection.length; i++) {
            (uint256 assetPrice, bool invalid) = IPerpMarket(_protection[i].market).assetPrice();
            (uint256 liquidationPrice, bool invalid2) = IPerpMarket(_protection[i].market).liquidationPrice(user);
            require(!(invalid || invalid2));

            if (isDanger(liquidationPrice, assetPrice, _protection[i].threshold) && _protection[i].action == false) {
                marketsToClose[length++] = _protection[i];
            }
        }
        _closeMarket(user, marketsToClose, length);
    }

    // Check for market rebalance
    function executeV2(address user) external nonReentrant requiresAuth onlyAllowed(user) {
        bool canRebalance = false;
        Protection[] memory _protection = protections[user];
        for (uint256 i = 0; i < _protection.length; i++) {
            (uint256 assetPrice, bool invalid) = IPerpMarket(_protection[i].market).assetPrice();
            (uint256 liquidationPrice, bool invalid2) = IPerpMarket(_protection[i].market).liquidationPrice(user);
            require(!(invalid || invalid2));

            if (isDanger(liquidationPrice, assetPrice, _protection[i].threshold) && _protection[i].action) {
                canRebalance = true;
                break;
            }
        }
        if (canRebalance) {
            _rebalanceMargin(user, _protection);
        }
    }

    function executeV3(address user) external nonReentrant requiresAuth onlyAllowed(user) {}

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

    /// -----------------------------------------------------------------------
    /// Admin Actions
    /// -----------------------------------------------------------------------

    function updateFeeReceipient(address _feeReceipeint) external requiresAuth {
        feeReceipient = _feeReceipeint;
    }

    /// @notice Update fee
    /// @param _flatFee New flat fee rate
    /// @param _percentageFee New percentage fee rate
    function updateFees(uint256 _flatFee, uint256 _percentageFee) external requiresAuth {
        flatFee = _flatFee;
        percentageFee = _percentageFee;
    }
}
