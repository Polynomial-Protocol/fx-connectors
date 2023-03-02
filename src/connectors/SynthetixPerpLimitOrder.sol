// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseConnector} from "../utils/BaseConnector.sol";

interface ILimitOrder {
    struct Request {
        bool isUpper;
        uint256 requestPrice;
        uint256 triggerPrice;
        uint256 limitPrice;
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
    }

    function submitLimitOrderRequest(address market, Request memory request) external;

    function cancelLimitOrderRequest(uint256 orderId) external;
}

interface IAccount {
    function isAuth(address user) external view returns (bool);
    function enable(address user) external;
    function disable(address user) external;
}

contract SynthetixPerpLimitOrderConnector is BaseConnector {
    ILimitOrder public immutable limitOrder;
    string public constant name = "Synthetix-Perp-Limit-Order-v1";

    constructor(ILimitOrder _limitOrder) {
        limitOrder = _limitOrder;
    }

    function submitLimitOrder(address market, ILimitOrder.Request memory request)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        bool isAuth = IAccount(address(this)).isAuth(address(limitOrder));

        if (!isAuth) {
            IAccount(address(this)).enable(address(limitOrder));
        }

        limitOrder.submitLimitOrderRequest(market, request);

        _eventName = "LogSubmitLimitOrder(address)";
        _eventParam = abi.encode(market);
    }

    function cancelLimitOrder(uint256 orderId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        limitOrder.cancelLimitOrderRequest(orderId);

        bool isAuth = IAccount(address(this)).isAuth(address(limitOrder));

        if (isAuth) {
            IAccount(address(this)).disable(address(limitOrder));
        }

        _eventName = "LogCancelLimitOrder(uint256)";
        _eventParam = abi.encode(orderId);
    }

    event LogSubmitLimitOrder(address indexed market);
    event LogCancelLimitOrder(uint256 orderId);
}