// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";
import {ReentrancyGuardUpgradable} from "../libraries/ReentracyUpgradable.sol";

interface IAccount {
    function cast(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin
    ) external;
    function isAuth(address user) external view returns (bool);
}

interface IList {
    function accountID(address) external view returns (uint64);
}

interface IPythNode {
    function getLatestPrice(
        bytes32 priceId,
        uint256 stalenessTolerance
    ) external view returns (int256);
}

contract SynthetixLimitOrdersV3 is
    Initializable,
    AuthUpgradable,
    ReentrancyGuardUpgradable
{
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Data Types
    /// -----------------------------------------------------------------------

    struct PriceRange {
        uint256 priceA;
        uint256 priceB;
        uint256 acceptablePrice;
    }

    struct OrderRequest {
        address user;
        PriceRange price;
        uint128 accountId;
        uint128 marketId;
        int128 size;
        uint128 expiry;
    }

    enum OrderStatus {
        SUBMITTED,
        EXECUTED,
        COMPLETED,
        CANCELLED
    }

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice SCW Index List
    IList public list;

    /// @notice Pyth Node
    IPythNode public pythNode;

    /// @notice Next order id
    uint256 public nextOrderId;

    /// @notice Market ID to Pyth Price ID mapping
    mapping(uint128 => bytes32) public priceIds;

    /// @notice Orders
    mapping(uint256 => OrderRequest) public orders;

    /// @notice Order status
    mapping(uint256 => OrderStatus) public status;

    /// @notice Storage gap
    uint256[50] private _gap;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OrderPlaced(
        address indexed user,
        uint128 indexed marketId,
        uint256 orderId,
        OrderRequest req
    );

    event OrderExec(
        address indexed user,
        uint128 indexed marketId,
        uint256 orderId,
        uint256 executionPrice
    );

    event OrderCancel(
        address indexed user,
        uint128 indexed marketId,
        uint256 orderId
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotScw(address user);
    error NotAuthorized(address user, address sender);
    error InvalidPriceRange(PriceRange price);
    error OrderExpired(uint256 expiry, uint256 currentTime);
    error PriceNotInRange(uint256 priceA, uint256 priceB, uint256 currentPrice);
    error OrderCancelled(uint256 orderId);
    error OrderExecuted(uint256 orderId);
    error OrderCompleted(uint256 orderId);
    error OrderSizeZero();

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

    function initialize(
        address _owner,
        address _list,
        address _pythNode
    ) public initializer {
        _auth_init(_owner, Authority(address(0x0)));
        _reentrancy_init();

        nextOrderId = 1;
        list = IList(_list);
        pythNode = IPythNode(_pythNode);
    }

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Place the order on-chain
     * @param req Order request
     */
    function placeOrder(OrderRequest memory req) external onlyScw {
        uint256 orderId = nextOrderId++;
        orders[orderId] = req;

        if (req.user != msg.sender) {
            revert NotAuthorized(req.user, msg.sender);
        }

        if (!_isPriceValid(req.price)) {
            status[orderId] = OrderStatus.EXECUTED;
        }

        emit OrderPlaced(req.user, req.marketId, orderId, req);
    }

    /**
     * @notice Execute main limit order
     * @param orderId Order ID
     */
    function executeOrder(uint256 orderId) external nonReentrant {
        OrderRequest memory order = orders[orderId];

        if (block.timestamp > order.expiry) {
            revert OrderExpired(order.expiry, block.timestamp);
        }

        if (status[orderId] == OrderStatus.CANCELLED) {
            revert OrderCancelled(orderId);
        }

        if (status[orderId] == OrderStatus.EXECUTED) {
            revert OrderExecuted(orderId);
        }

        if (status[orderId] == OrderStatus.COMPLETED) {
            revert OrderCompleted(orderId);
        }

        if (order.size == 0) {
            revert OrderSizeZero();
        }

        (bool isValid, uint256 currentPrice) = _isOrderValid(
            order.marketId,
            order.price
        );

        if (!isValid) {
            revert PriceNotInRange(
                order.price.priceA,
                order.price.priceB,
                currentPrice
            );
        }

        _castSpells(orderId, order, currentPrice);
    }

    /**
     * @notice Cancel Order
     * @param orderId Order ID
     */
    function cancelOrder(uint256 orderId) external {
        OrderRequest memory order = orders[orderId];

        if (msg.sender != order.user) {
            revert NotAuthorized(order.user, msg.sender);
        }

        status[orderId] = OrderStatus.CANCELLED;

        emit OrderCancel(order.user, order.marketId, orderId);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Generate spells to cast
     * @param orderId Order ID
     * @param order Order request
     * @param currentPrice Current price at execution time
     */
    function _castSpells(
        uint256 orderId,
        OrderRequest memory order,
        uint256 currentPrice
    ) internal {
        string[] memory targetNames = new string[](1);
        bytes[] memory datas = new bytes[](1);

        targetNames[0] = "Synthetix-Perp-v3-v1.2";

        datas[0] = abi.encodeWithSignature(
            "commitTrade(uint128,uint128,int128,uint256)",
            order.accountId,
            order.marketId,
            order.size,
            order.price.acceptablePrice
        );

        status[orderId] = OrderStatus.COMPLETED;

        IAccount(order.user).cast(targetNames, datas, address(this));

        emit OrderExec(order.user, order.marketId, orderId, currentPrice);
    }

    /**
     * @notice Checks whether the price range is valid to execute now
     * @param marketId Market ID
     * @param range Price range
     */
    function _isOrderValid(
        uint128 marketId,
        PriceRange memory range
    ) internal view returns (bool, uint256) {
        bytes32 priceId = priceIds[marketId];
        uint256 currentPrice = uint256(pythNode.getLatestPrice(priceId, 0));

        return (
            currentPrice >= range.priceA && currentPrice <= range.priceB,
            currentPrice
        );
    }

    /**
     * @notice Returns whether the price range is valid or not
     * @param price price range object
     */
    function _isPriceValid(
        PriceRange memory price
    ) internal pure returns (bool) {
        if (price.priceA == 0 || price.priceB == 0) {
            return false;
        }

        if (price.priceA > price.priceB) {
            return false;
        }

        return true;
    }

    /// -----------------------------------------------------------------------
    /// Admin functions
    /// -----------------------------------------------------------------------

    function updatePriceIds(
        uint128[] calldata _marketIds,
        bytes32[] calldata _priceIds
    ) external requiresAuth {
        if (_marketIds.length != _priceIds.length) {
            revert LengthMismatch();
        }

        for (uint256 i = 0; i < _marketIds.length; i++) {
            priceIds[_marketIds[i]] = _priceIds[i];
        }
    }

    function sweep() external requiresAuth {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyScw() {
        if (list.accountID(msg.sender) == 0) {
            revert NotScw(msg.sender);
        }
        _;
    }
}
