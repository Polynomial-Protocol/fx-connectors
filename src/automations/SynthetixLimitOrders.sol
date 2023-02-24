// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IList {
    function accountID(address) external view returns (uint64);
}

interface IPerpMarket {
    function assetPrice() external view returns (uint256 price, bool invalid);
}

contract SynthetixLimitOrders {
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

    uint256 public orderCount = 1;

    mapping(uint256 => LimitOrder) limitOrders;

    function submitLimitOrderRequest(
        address market,
        bool isUpper,
        uint256 triggerPrice,
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 expiry
    ) external {
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

    function cancelLimitOrderRequest(uint256 orderId) external {
        LimitOrder memory order = limitOrders[orderId];
        require(msg.sender == order.user);

        emit CancelRequest(order.market, msg.sender, orderId);

        delete limitOrders[orderId];
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
}
