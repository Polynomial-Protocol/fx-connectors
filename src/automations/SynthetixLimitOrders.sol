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
}

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
}

contract SynthetixLimitOrders is Initializable, AuthUpgradable, ReentrancyGuardUpgradable {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Data Types
    /// -----------------------------------------------------------------------

    struct LimitOrder {
        bool isExecuted;
        address user;
        address market;
        bool isUpper;
        uint256 requestPrice;
        uint256 triggerPrice;
        uint256 limitPrice;
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
    }

    struct Request {
        bool isUpper;
        uint256 triggerPrice;
        uint256 limitPrice;
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
    }

    /// -----------------------------------------------------------------------
    /// State Variables
    /// -----------------------------------------------------------------------

    /// @notice Flat fee charged per each order, taken from margin upon execution
    uint256 public flatFee;

    /// @notice Percentage fee charged per each order (or dollar value)
    uint256 public percentageFee;

    /// @notice Next order id
    uint256 public nextOrderId;

    /// @notice Order id to order info mapping
    mapping(uint256 => LimitOrder) public limitOrders;

    // constructor() Auth(msg.sender, Authority(address(0x0))) {}

    function initialize(address _owner, uint256 _flatFee, uint256 _percentageFee) public initializer {
        _auth_init(_owner, Authority(0x19828283852a852f8cFfF4696038Bc19E5070A49));
        _reentrancy_init();

        emit UpdateFees(flatFee, _flatFee, percentageFee, _percentageFee);

        flatFee = _flatFee;
        percentageFee = _percentageFee;

        nextOrderId = 1;
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    /// @notice Submit a new limit order request
    /// @param market Address of the perp v2 market
    /// @param request Request details
    function submitLimitOrderRequest(address market, Request memory request) external nonReentrant {
        require(isAllowed());
        require(request.expiry > block.timestamp, "invalid-expiry");

        (uint256 requestPrice, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid, "invalid-current-price");

        require(
            request.isUpper ? request.triggerPrice > requestPrice : requestPrice > request.triggerPrice,
            "invalid-trigger-price"
        );
        require(
            request.isUpper ? request.limitPrice > request.triggerPrice : request.triggerPrice > request.limitPrice,
            "invalid-limit-price"
        );

        LimitOrder storage order = limitOrders[nextOrderId++];

        order.user = msg.sender;
        order.market = market;
        order.isUpper = request.isUpper;
        order.requestPrice = requestPrice;
        order.triggerPrice = request.triggerPrice;
        order.limitPrice = request.limitPrice;
        order.sizeDelta = request.sizeDelta;
        order.priceImpactDelta = request.priceImpactDelta;
        order.expiry = request.expiry;

        emit SubmitRequest(
            market,
            order.user,
            nextOrderId - 1,
            request.isUpper,
            requestPrice,
            request.triggerPrice,
            request.limitPrice,
            request.sizeDelta,
            request.priceImpactDelta,
            request.expiry
        );
    }

    /// @notice Cancel a limit order request
    /// @param orderId Order id to cancel
    function cancelLimitOrderRequest(uint256 orderId) external nonReentrant {
        LimitOrder memory order = limitOrders[orderId];
        require(msg.sender == order.user, "unauthorized");

        emit CancelRequest(order.market, msg.sender, orderId);

        delete limitOrders[orderId];
    }

    /// -----------------------------------------------------------------------
    /// Keeper Actions
    /// -----------------------------------------------------------------------

    /// @notice Execute a limit order
    /// @param orderId Order id to execute
    /// @param feeReceipient Address of the fee receipient
    function executeLimitOrder(uint256 orderId, address feeReceipient) external nonReentrant requiresAuth {
        LimitOrder storage order = limitOrders[orderId];
        require(block.timestamp <= order.expiry && !order.isExecuted, "already-expired-or-already-executed");

        (uint256 currentPrice, bool invalid) = IPerpMarket(order.market).assetPrice();
        require(!invalid, "invalid-current-price");

        require(
            order.isUpper ? currentPrice >= order.triggerPrice : currentPrice <= order.triggerPrice,
            "did-not-satisfy-trigger"
        );

        require(
            order.isUpper ? currentPrice <= order.limitPrice : order.limitPrice <= currentPrice, "did-not-satisfy-limit"
        );

        uint256 dollarValue = _abs(order.sizeDelta).mulWadDown(currentPrice);
        uint256 totalFees = flatFee + dollarValue.mulWadDown(percentageFee);

        string[] memory targets = new string[](3);
        bytes[] memory datas = new bytes[](3);

        targets[0] = "Synthetix-Perp-v1.4";
        datas[0] =
            abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

        targets[1] = "Synthetix-Perp-v1.4";
        datas[1] = abi.encodeWithSignature(
            "trade(address,int256,uint256)", order.market, order.sizeDelta, order.priceImpactDelta
        );

        targets[2] = "Basic-v1";
        datas[2] = abi.encodeWithSignature(
            "withdraw(address,uint256,address,uint256,uint256)",
            0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9,
            totalFees,
            feeReceipient,
            0,
            0
        );

        IAccount(order.user).cast(targets, datas, address(0x0));

        emit ExecuteRequest(order.market, order.user, orderId, currentPrice, msg.sender, feeReceipient, totalFees);

        order.isExecuted = true;
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

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

    /// -----------------------------------------------------------------------
    /// Admin Actions
    /// -----------------------------------------------------------------------

    /// @notice Update fee
    /// @param _flatFee New flat fee rate
    /// @param _percentageFee New percentage fee rate
    function updateFees(uint256 _flatFee, uint256 _percentageFee) external requiresAuth {
        emit UpdateFees(flatFee, _flatFee, percentageFee, _percentageFee);

        flatFee = _flatFee;
        percentageFee = _percentageFee;
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when a new request is submitted
    /// @param market Address of the market
    /// @param user Address of the user
    /// @param requestId Request / Order ID
    /// @param isUpper Whether the trigger is crossing above trigger price or below
    /// @param requestPrice Price at the time of request
    /// @param triggerPrice Trigger price
    /// @param limitPrice Upper or lower limit price for the trigger
    /// @param sizeDelta Limit order size
    /// @param priceImpactDelta Price impact delta of limit order
    /// @param expiry Expiry time stamp of the limit order
    event SubmitRequest(
        address indexed market,
        address indexed user,
        uint256 requestId,
        bool isUpper,
        uint256 requestPrice,
        uint256 triggerPrice,
        uint256 limitPrice,
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 expiry
    );

    /// @notice Emitted when a limit order request is cancelled
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param requestId Request / Order id
    event CancelRequest(address indexed market, address indexed user, uint256 requestId);

    /// @notice Emitted when the limit order request is executed
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param requestId Request / Order id
    /// @param executionPrice Price at the time of execution
    /// @param keeper Address of the keeper
    /// @param feeReceipient Address of the fee receipient
    /// @param totalFee Total fees charged from the user
    event ExecuteRequest(
        address indexed market,
        address indexed user,
        uint256 requestId,
        uint256 executionPrice,
        address keeper,
        address feeReceipient,
        uint256 totalFee
    );

    /// @notice Emitted when fees are updated
    /// @param oldFlat Old flat fee rate
    /// @param newFlat New flat fee rate
    /// @param oldPercentage Old percentage fee rate
    /// @param newPercentage New percentage fee rate
    event UpdateFees(uint256 oldFlat, uint256 newFlat, uint256 oldPercentage, uint256 newPercentage);
}
