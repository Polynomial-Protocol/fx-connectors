// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseConnector} from "../utils/BaseConnector.sol";

interface IAdvancedOrders {
    struct FullOrderRequest {
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
        uint256 priceA;
        uint256 priceB;
        uint256 firstPairA;
        uint256 firstPairB;
        uint256 secondPairA;
        uint256 secondPairB;
    }

    struct PairOrderRequest {
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
        uint256 firstPairA;
        uint256 firstPairB;
        uint256 secondPairA;
        uint256 secondPairB;
    }

    function submitFullOrder(address market, FullOrderRequest memory request) external;

    function submitPairOrder(address market, PairOrderRequest memory request) external;

    function addPairOrder(uint256 id, PairOrderRequest memory request) external;

    function cancelFullOrder(uint256 orderId) external;

    function cancelPairOrder(uint256 orderId) external;

    function cancelIndividualOrder(uint256 orderId, bool isFirst) external;
}

interface IAccount {
    function isAuth(address user) external view returns (bool);
    function enable(address user) external;
    function disable(address user) external;
}

interface IPerpMarket {
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    function positions(address account) external view returns (Position memory);
}

contract SynthetixAdvancedOrdersConnector is BaseConnector {
    IAdvancedOrders public constant advancedOrders = IAdvancedOrders(0x7634E43aA3f446C8d9D5014d609355F728361075);

    string public constant name = "Synthetix-Advanced-Orders-v1";

    function submitFullOrder(address market, IAdvancedOrders.FullOrderRequest memory request)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        bool isAuth = IAccount(address(this)).isAuth(address(advancedOrders));

        if (!isAuth) {
            IAccount(address(this)).enable(address(advancedOrders));
        }

        advancedOrders.submitFullOrder(market, request);

        _eventName = "LogSubmitFullOrder(address)";
        _eventParam = abi.encode(market);
    }

    function submitPairOrder(address market, IAdvancedOrders.PairOrderRequest memory request)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        bool isAuth = IAccount(address(this)).isAuth(address(advancedOrders));

        if (!isAuth) {
            IAccount(address(this)).enable(address(advancedOrders));
        }

        advancedOrders.submitPairOrder(market, request);

        _eventName = "LogSubmitPairOrder(address)";
        _eventParam = abi.encode(market);
    }

    function addPairOrder(uint256 id, IAdvancedOrders.PairOrderRequest memory request)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        bool isAuth = IAccount(address(this)).isAuth(address(advancedOrders));

        if (!isAuth) {
            IAccount(address(this)).enable(address(advancedOrders));
        }

        advancedOrders.addPairOrder(id, request);

        _eventName = "LogAddPairOrder(uint256)";
        _eventParam = abi.encode(id);
    }

    function cancelFullOrder(uint256 id) public payable returns (string memory _eventName, bytes memory _eventParam) {
        advancedOrders.cancelFullOrder(id);

        _eventName = "LogCancelFullOrder(uint256)";
        _eventParam = abi.encode(id);
    }

    function cancelPairOrder(uint256 id) public payable returns (string memory _eventName, bytes memory _eventParam) {
        advancedOrders.cancelPairOrder(id);

        _eventName = "LogCancelPairOrder(uint256)";
        _eventParam = abi.encode(id);
    }

    function cancelIndividualOrder(uint256 id, bool isFirst)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        advancedOrders.cancelPairOrder(id);

        _eventName = "LogCancelIndividualOrder(uint256,bool)";
        _eventParam = abi.encode(id, isFirst);
    }

    event LogSubmitFullOrder(address indexed market);
    event LogSubmitPairOrder(address indexed market);
    event LogAddPairOrder(uint256 indexed id);
    event LogCancelFullOrder(uint256 indexed id);
    event LogCancelPairOrder(uint256 indexed id);
    event LogCancelIndividualOrder(uint256 indexed id, bool isFirst);
}
