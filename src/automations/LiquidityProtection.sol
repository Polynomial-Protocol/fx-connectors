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
        address market;
        bool action; //0 represents close, 1 represents rebalance
        uint256 threshold;
        bool isProtected;
        address user;
    }

    mapping(address => Protection) public protection;
    mapping(address => bool) public isPresent;
    address[] public markets;

    function updateProtection(address[] memory _markets, Protection[] memory _protections)
        external
        nonReentrant
        requiresAuth
    {
        require(isAllowed());

        for (uint256 i = 0; i < markets.length; i++) {
            require(_protections[i].threshold != uint256(0));

            if (isPresent[_markets[i]] == false) {
                isPresent[_markets[i]] = true;
                markets.push(_markets[i]);
            }

            protection[_markets[i]] = _protections[i];
        }
    }

    function _rebalanceMargin() internal {}

    function _closeMarket() internal {}

    function execute() external nonReentrant requiresAuth {
        require(isAllowed());
        bool canRebalance = false;
        for (uint256 i = 0; i < markets.length; i++) {
            (uint256 assetPrice, bool invalid) = IPerpMarket(markets[i]).assetPrice();
            (uint256 liquidationPrice, bool invalid2) = IPerpMarket(markets[i]).liquidationPrice(msg.sender);
            require(!(invalid || invalid2));

            Protection memory _protection = protection[markets[i]];
            if (_protection.isProtected) {
                if (isDanger(liquidationPrice, assetPrice, _protection.threshold) && _protection.action) {
                    canRebalance = true;
                    break;
                }
            }
        }
        if (canRebalance) {
            _rebalanceMargin();
        }
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
