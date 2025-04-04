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

interface IOrderValidator {
    function validateOrder(
        uint256 orderId,
        uint128 marketId,
        int128 size
    ) external view returns (bool, uint256);
}

interface IPolynomialPortalOrders {
    struct OrderRequest {
        address user;
        uint128 accountId;
        uint128 marketId;
        int128 size;
        uint128 expiry;
        address validator;
    }

    function placeOrder(OrderRequest memory req) external returns (uint256);
    function executeOrder(uint256 orderId) external;
}

/**
 * @title PolynomialPortal
 * @notice A contract that facilitates the creation and execution of orders with external validators
 */
contract PolynomialPortal is
    IPolynomialPortalOrders,
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

    enum OrderStatus {
        SUBMITTED,
        EXECUTED,
        COMPLETED,
        CANCELLED
    }

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice SCW Index List for authentication
    IList public list;

    /// @notice Next order id
    uint256 public nextOrderId;

    /// @notice Storage gap for upgradeable contracts
    uint256[50] private __gap;

    /// @notice Orders mapping
    mapping(uint256 => OrderRequest) public orders;

    /// @notice Order status mapping
    mapping(uint256 => OrderStatus) public status;

    /// @notice Validator to order IDs mapping
    mapping(address => uint256[]) public validatorOrders;

    /// @notice Order ID to validator mapping
    mapping(uint256 => address) public orderValidator;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OrderPlaced(
        address indexed user,
        uint128 indexed marketId,
        uint256 orderId,
        OrderRequest req
    );

    event OrderExecuted(
        address indexed user,
        uint128 indexed marketId,
        uint256 orderId,
        uint256 executionPrice
    );

    event OrderCancelled(
        address indexed user,
        uint128 indexed marketId,
        uint256 orderId
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotScw(address user);
    error NotAuth(address signer);
    error NotAuthorized(address user, address sender);
    error OrderCancelled(uint256 orderId);
    error OrderExecuted(uint256 orderId);
    error OrderCompleted(uint256 orderId);
    error OrderExpired(uint256 orderExpiry, uint256 blockTimestamp);
    error OrderSizeZero();
    error OrderValidationFailed(uint256 orderId);

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

    /**
     * @notice Initializes the contract
     * @param _owner Address of the contract owner
     * @param _list Address of the SCW index list
     */
    function initialize(address _owner, address _list) public initializer {
        _auth_init(_owner, Authority(address(0x0)));
        _reentrancy_init();

        nextOrderId = 1;
        list = IList(_list);
    }

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Places an order through a validator
     * @param req Order request containing user, marketId, size, etc.
     * @return orderId The ID of the placed order
     */
    function placeOrder(
        OrderRequest memory req
    ) external override onlyScw returns (uint256) {
        if (req.user != msg.sender) {
            revert NotAuthorized(req.user, msg.sender);
        }

        if (req.size == 0) {
            revert OrderSizeZero();
        }

        uint256 orderId = nextOrderId++;
        orders[orderId] = req;
        orderValidator[orderId] = req.validator;
        validatorOrders[req.validator].push(orderId);
        status[orderId] = OrderStatus.SUBMITTED;

        emit OrderPlaced(req.user, req.marketId, orderId, req);

        return orderId;
    }

    /**
     * @notice Executes an order after validation
     * @param orderId The ID of the order to execute
     */
    function executeOrder(uint256 orderId) external override nonReentrant {
        OrderRequest memory order = orders[orderId];

        if (msg.sender != order.validator) {
            revert NotAuthorized(order.validator, msg.sender);
        }

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

        (bool isValid, uint256 currentPrice) = IOrderValidator(order.validator)
            .validateOrder(orderId, order.marketId, order.size);

        if (!isValid) {
            revert OrderValidationFailed(orderId);
        }

        _executeOrder(orderId, order, currentPrice);
    }

    /**
     * @notice Cancels an order
     * @param orderId The ID of the order to cancel
     */
    function cancelOrder(uint256 orderId) external {
        OrderRequest memory order = orders[orderId];

        if (msg.sender != order.user) {
            revert NotAuthorized(order.user, msg.sender);
        }

        status[orderId] = OrderStatus.CANCELLED;

        emit OrderCancelled(order.user, order.marketId, orderId);
    }

    /**
     * @notice Get all orders for a specific validator
     * @param validator The address of the validator
     * @return Array of order IDs for the validator
     */
    function getValidatorOrders(
        address validator
    ) external view returns (uint256[] memory) {
        return validatorOrders[validator];
    }

    /**
     * @notice Get all active orders for a user
     * @param user The address of the user
     * @return activeOrders Array of active order IDs for the user
     */
    function getUserActiveOrders(
        address user
    ) external view returns (uint256[] memory) {
        uint256 count = 0;

        // First, count how many active orders the user has
        for (uint256 i = 1; i < nextOrderId; i++) {
            if (orders[i].user == user && status[i] == OrderStatus.SUBMITTED) {
                count++;
            }
        }

        // Create array of the right size
        uint256[] memory activeOrders = new uint256[](count);

        // Fill the array
        uint256 index = 0;
        for (uint256 i = 1; i < nextOrderId; i++) {
            if (orders[i].user == user && status[i] == OrderStatus.SUBMITTED) {
                activeOrders[index] = i;
                index++;
            }
        }

        return activeOrders;
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Internal function to execute an order
     * @param orderId The ID of the order
     * @param order The order data
     * @param executionPrice The price at execution time
     */
    function _executeOrder(
        uint256 orderId,
        OrderRequest memory order,
        uint256 executionPrice
    ) internal {
        string[] memory targetNames = new string[](1);
        bytes[] memory datas = new bytes[](1);

        targetNames[0] = "Synthetix-Perp-v3-v1.2";

        datas[0] = abi.encodeWithSignature(
            "commitTrade(uint128,uint128,int128,uint256)",
            order.accountId,
            order.marketId,
            order.size,
            executionPrice
        );

        status[orderId] = OrderStatus.COMPLETED;

        IAccount(order.user).cast(targetNames, datas, address(this));

        emit OrderExecuted(order.user, order.marketId, orderId, executionPrice);
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
