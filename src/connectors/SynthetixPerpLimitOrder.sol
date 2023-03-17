// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseConnector} from "../utils/BaseConnector.sol";

interface ILimitOrder {
    struct Request {
        bool isUpper;
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
    ILimitOrder public constant limitOrder = ILimitOrder(0xc1F7a43Db81e7DC4b3F4C6C2AcdCBdC17C41b0Dc);

    string public constant name = "Synthetix-Perp-Limit-Order-v1.1";

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

    function cancelLimitOrder(uint256 orderId, bool toDisable)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        limitOrder.cancelLimitOrderRequest(orderId);

        bool isAuth = IAccount(address(this)).isAuth(address(limitOrder));

        if (isAuth && toDisable) {
            IAccount(address(this)).disable(address(limitOrder));
        }

        _eventName = "LogCancelLimitOrder(uint256,bool)";
        _eventParam = abi.encode(orderId, toDisable);
    }

    event LogSubmitLimitOrder(address indexed market);
    event LogCancelLimitOrder(uint256 orderId, bool toDisable);
}
