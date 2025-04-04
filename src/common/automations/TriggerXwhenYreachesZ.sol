// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";
import {ReentrancyGuardUpgradable} from "../libraries/ReentracyUpgradable.sol";

interface IPythNode {
    function getLatestPrice(
        bytes32 priceId,
        uint256 stalenessTolerance
    ) external view returns (int256);
}

interface ISynthetixLimitOrders {
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
 * @title TriggerXwhenYreachesZ
 * @notice A validator contract for executing orders on a specific market when price conditions for other markets are met
 */
contract TriggerXwhenYreachesZ is
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
    }

    struct OrderDetails {
        address user;
        uint128 accountId;
        uint128[] marketIds;
        PriceRange[] priceRanges;
        uint128 orderMarketId;
        int128 orderSize;
        uint128 expiry;
    }

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    /// @notice Synthetix Limit Orders contract
    ISynthetixLimitOrders public limitOrders;

    /// @notice Pyth Node for price data
    IPythNode public pythNode;

    /// @notice Market ID to Pyth Price ID mapping
    mapping(uint128 => bytes32) public priceIds;

    /// @notice Order ID to Order Details mapping
    mapping(uint256 => OrderDetails) public orders;

    /// @notice Storage gap for upgradeable contracts
    uint256[50] private __gap;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event OrderPlaced(
        address indexed user,
        uint256 indexed orderId,
        uint128 orderMarketId,
        int128 orderSize,
        uint128[] marketIds,
        PriceRange[] priceRanges
    );

    event OrderExecuted(
        uint256 indexed orderId,
        uint128 orderMarketId,
        int128 orderSize,
        uint256 executionPrice
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error MismatchedArrayLengths();
    error InvalidPriceRange();
    error OrderExpired(uint256 expiry, uint256 currentTime);
    error PriceConditionNotMet(
        uint128 marketId,
        uint256 currentPrice,
        uint256 priceA,
        uint256 priceB
    );
    error OrderDoesNotExist(uint256 orderId);
    error Unauthorized(address caller, address user);

    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------

    /**
     * @notice Initializes the contract
     * @param _owner Address of the contract owner
     * @param _limitOrders Address of the Synthetix Limit Orders contract
     * @param _pythNode Address of the Pyth Node contract
     */
    function initialize(
        address _owner,
        address _limitOrders,
        address _pythNode
    ) public initializer {
        _auth_init(_owner, Authority(address(0x0)));
        _reentrancy_init();

        limitOrders = ISynthetixLimitOrders(_limitOrders);
        pythNode = IPythNode(_pythNode);
    }

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Places an order that will execute on orderMarketId when price conditions for marketIds are met
     * @param marketIds Array of market IDs to monitor for price conditions
     * @param priceRanges Array of price ranges corresponding to each market ID
     * @param orderSize Size of the order to execute
     * @param orderMarketId Market ID to execute the order on
     * @param accountId Account ID for the trade
     * @param expiry Expiry timestamp for the order
     * @return orderId The ID of the placed order
     */
    function placeOrder(
        uint128[] calldata marketIds,
        PriceRange[] calldata priceRanges,
        int128 orderSize,
        uint128 orderMarketId,
        uint128 accountId,
        uint128 expiry
    ) external returns (uint256) {
        if (marketIds.length != priceRanges.length) {
            revert MismatchedArrayLengths();
        }

        // Validate price ranges
        for (uint256 i = 0; i < priceRanges.length; i++) {
            if (
                priceRanges[i].priceA > priceRanges[i].priceB ||
                priceRanges[i].priceA == 0 ||
                priceRanges[i].priceB == 0
            ) {
                revert InvalidPriceRange();
            }
        }

        // Create an order request for the SynthetixLimitOrdersV3 contract
        ISynthetixLimitOrders.OrderRequest memory req = ISynthetixLimitOrders
            .OrderRequest({
                user: msg.sender,
                accountId: accountId,
                marketId: orderMarketId,
                size: orderSize,
                expiry: expiry,
                validator: address(this)
            });

        // Place the order and get the order ID
        uint256 orderId = limitOrders.placeOrder(req);

        // Store the order details in our contract
        orders[orderId] = OrderDetails({
            user: msg.sender,
            accountId: accountId,
            marketIds: marketIds,
            priceRanges: priceRanges,
            orderMarketId: orderMarketId,
            orderSize: orderSize,
            expiry: expiry
        });

        emit OrderPlaced(
            msg.sender,
            orderId,
            orderMarketId,
            orderSize,
            marketIds,
            priceRanges
        );

        return orderId;
    }

    /**
     * @notice Executes an order if all price conditions are met
     * @param orderId The ID of the order to execute
     */
    function executeOrder(uint256 orderId) external nonReentrant {
        OrderDetails memory order = orders[orderId];

        if (order.user == address(0)) {
            revert OrderDoesNotExist(orderId);
        }

        if (block.timestamp > order.expiry) {
            revert OrderExpired(order.expiry, block.timestamp);
        }

        // Check if price conditions are met for all market IDs
        for (uint256 i = 0; i < order.marketIds.length; i++) {
            uint128 marketId = order.marketIds[i];
            PriceRange memory range = order.priceRanges[i];

            bytes32 priceId = priceIds[marketId];
            uint256 currentPrice = uint256(pythNode.getLatestPrice(priceId, 0));

            if (currentPrice < range.priceA || currentPrice > range.priceB) {
                revert PriceConditionNotMet(
                    marketId,
                    currentPrice,
                    range.priceA,
                    range.priceB
                );
            }
        }

        // If all conditions are met, execute the order
        limitOrders.executeOrder(orderId);

        // Get the execution price for the event (optional)
        bytes32 priceId = priceIds[order.orderMarketId];
        uint256 executionPrice = uint256(pythNode.getLatestPrice(priceId, 0));

        emit OrderExecuted(
            orderId,
            order.orderMarketId,
            order.orderSize,
            executionPrice
        );
    }

    /**
     * @notice Validates an order for the SynthetixLimitOrdersV3 contract
     * @param orderId The ID of the order to validate
     * @param marketId The market ID of the order
     * @param size The size of the order
     * @return isValid Whether the order is valid
     * @return currentPrice The current price of the market
     */
    function validateOrder(
        uint256 orderId,
        uint128 marketId,
        int128 size
    ) external view returns (bool isValid, uint256 currentPrice) {
        OrderDetails memory order = orders[orderId];

        if (order.user == address(0)) {
            return (false, 0);
        }

        if (block.timestamp > order.expiry) {
            return (false, 0);
        }

        bytes32 orderPriceId = priceIds[marketId];
        currentPrice = uint256(pythNode.getLatestPrice(orderPriceId, 0));

        // Check all price conditions
        for (uint256 i = 0; i < order.marketIds.length; i++) {
            uint128 conditionMarketId = order.marketIds[i];
            PriceRange memory range = order.priceRanges[i];

            bytes32 conditionPriceId = priceIds[conditionMarketId];
            uint256 conditionPrice = uint256(
                pythNode.getLatestPrice(conditionPriceId, 0)
            );

            if (
                conditionPrice < range.priceA || conditionPrice > range.priceB
            ) {
                return (false, currentPrice);
            }
        }

        return (true, currentPrice);
    }

    /// -----------------------------------------------------------------------
    /// Admin functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Updates the price IDs for market IDs
     * @param _marketIds Array of market IDs
     * @param _priceIds Array of corresponding price IDs
     */
    function updatePriceIds(
        uint128[] calldata _marketIds,
        bytes32[] calldata _priceIds
    ) external requiresAuth {
        if (_marketIds.length != _priceIds.length) {
            revert MismatchedArrayLengths();
        }

        for (uint256 i = 0; i < _marketIds.length; i++) {
            priceIds[_marketIds[i]] = _priceIds[i];
        }
    }
}
