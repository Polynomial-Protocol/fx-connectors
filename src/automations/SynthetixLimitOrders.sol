// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

interface IList {
    function accountID(address) external view returns (uint64);
}

interface IPerpMarket {
    function assetPrice() external view returns (uint256 price, bool invalid);
}

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
}

contract SynthetixLimitOrders is ReentrancyGuard {
    using FixedPointMathLib for uint256;

    struct LimitOrder {
        address user;
        address market;
        bool isUpper;
        uint256 requestPrice;
        uint256 triggerPrice;
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
    }

    uint256 public constant WAD = 1e18;

    uint256 public orderCount = 1;

    mapping(uint256 => LimitOrder) limitOrders;

    function submitLimitOrderRequest(
        address market,
        bool isUpper,
        uint256 triggerPrice,
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 expiry
    ) external nonReentrant {
        require(isAllowed());
        require(expiry > block.timestamp);

        (uint256 requestPrice, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid);

        require(isUpper ? triggerPrice > requestPrice : requestPrice > triggerPrice);

        LimitOrder memory order = limitOrders[orderCount++];

        order.user = msg.sender;
        order.market = market;
        order.isUpper = isUpper;
        order.requestPrice = requestPrice;
        order.triggerPrice = triggerPrice;
        order.sizeDelta = sizeDelta;
        order.priceImpactDelta = priceImpactDelta;
        order.expiry = expiry;

        emit SubmitRequest(
            market, order.user, orderCount - 1, isUpper, requestPrice, triggerPrice, sizeDelta, priceImpactDelta, expiry
            );
    }

    function cancelLimitOrderRequest(uint256 orderId) external nonReentrant {
        LimitOrder memory order = limitOrders[orderId];
        require(msg.sender == order.user);

        emit CancelRequest(order.market, msg.sender, orderId);

        delete limitOrders[orderId];
    }

    function executeLimitOrder(uint256 orderId, address feeReceipient) external nonReentrant {
        LimitOrder memory order = limitOrders[orderId];
        require(block.timestamp <= order.expiry);

        (uint256 currentPrice, bool invalid) = IPerpMarket(order.market).assetPrice();
        require(!invalid);

        require(order.isUpper ? currentPrice >= order.triggerPrice : currentPrice <= order.triggerPrice);
        uint256 maxPrice =
            order.triggerPrice.mulWadDown(order.isUpper ? WAD + order.priceImpactDelta : WAD - order.priceImpactDelta);
        require(order.isUpper ? currentPrice < maxPrice : maxPrice > currentPrice);

        string[] memory targets = new string[](3);
        bytes[] memory datas = new bytes[](3);

        targets[0] = "Synthetix-Perp-v1";
        datas[0] = abi.encodeWithSignature(
            "trade(address,int256,uint256)", order.market, order.sizeDelta, order.priceImpactDelta
        );

        targets[1] = "Synthetix-Perp-v1";
        datas[1] = abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, 2e18, 0, 0);

        targets[2] = "Basic-v1";
        datas[2] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9,
            2e18,
            feeReceipient,
            0,
            0
        );

        IAccount(order.user).cast(targets, datas, address(0x0));

        emit ExecuteRequest(order.market, order.user, orderId, currentPrice, msg.sender, feeReceipient);
    }

    function isAllowed() internal view returns (bool) {
        return IList(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B).accountID(msg.sender) != 0;
    }

    event SubmitRequest(
        address indexed market,
        address indexed user,
        uint256 requestId,
        bool isUpper,
        uint256 requestPrice,
        uint256 triggerPrice,
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 expiry
    );

    event CancelRequest(address indexed market, address indexed user, uint256 requestId);

    event ExecuteRequest(
        address indexed market,
        address indexed user,
        uint256 requestId,
        uint256 executionPrice,
        address keeper,
        address feeReceipient
    );
}
