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
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    function positions(address account) external view returns (Position memory);

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

    struct FullOrder {
        bool isStarted;
        bool isCompleted;
        bool isCancelled;
        address user;
        address market;
        int256 sizeDelta;
        uint256 priceImpactDelta;
        uint256 expiry;
        uint256 requestPrice;
        uint256 priceA;
        uint256 priceB;
        uint256 firstPairA;
        uint256 firstPairB;
        uint256 secondPairA;
        uint256 secondPairB;
    }

    /// -----------------------------------------------------------------------
    /// State Variables
    /// -----------------------------------------------------------------------

    /// @notice Address of the fee receipient
    address public feeReceipient;

    /// @notice Flat fee charged per each order, taken from margin upon execution
    uint256 public flatFee;

    /// @notice Percentage fee charged per each order (or dollar value)
    uint256 public percentageFee;

    /// @notice Next full order id
    uint256 public nextFullOrderId;

    /// @notice Order id to order info mapping
    mapping(uint256 => FullOrder) public fullOrders;

    function initialize(address _owner, address _feeReceipient, uint256 _flatFee, uint256 _percentageFee)
        public
        initializer
    {
        _auth_init(_owner, Authority(0x19828283852a852f8cFfF4696038Bc19E5070A49));
        _reentrancy_init();

        emit UpdateFeeReceipient(feeReceipient, _feeReceipient);
        emit UpdateFees(flatFee, _flatFee, percentageFee, _percentageFee);

        feeReceipient = _feeReceipient;

        flatFee = _flatFee;
        percentageFee = _percentageFee;

        nextFullOrderId = 1;
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function submitFullOrder(address market, FullOrderRequest memory request) external nonReentrant {
        require(isAllowed());
        require(request.expiry > block.timestamp, "invalid-expiry");

        (uint256 requestPrice, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid && requestPrice != 0, "invalid-current-price");

        require(request.priceA != 0 && request.priceB != 0, "range-is-zero");
        require(request.priceB > request.priceA, "invalid-range");
        require(request.priceA > requestPrice || request.priceB < requestPrice, "invalid-range-for-current-price");

        FullOrder storage order = fullOrders[nextFullOrderId++];

        order.user = msg.sender;
        order.market = market;
        order.requestPrice = requestPrice;
        order.sizeDelta = request.sizeDelta;
        order.priceImpactDelta = request.priceImpactDelta;
        order.priceA = request.priceA;
        order.priceB = request.priceB;
        order.firstPairA = request.firstPairA;
        order.firstPairB = request.firstPairB;
        order.secondPairA = request.secondPairA;
        order.secondPairB = request.secondPairB;

        emit SubmitFullOrder(market, msg.sender, nextFullOrderId - 1, requestPrice, request);
    }

    function submitPairOrder(address market, PairOrderRequest memory request) external nonReentrant {
        require(isAllowed());
        require(request.expiry > block.timestamp, "invalid-expiry");

        (uint256 requestPrice, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid && requestPrice != 0, "invalid-current-price");

        require(request.firstPairA != 0 && request.firstPairA != 0, "range-is-zero");
        require(request.firstPairB > request.firstPairA, "invalid-range");
        require(
            request.firstPairA > requestPrice || request.firstPairB < requestPrice, "invalid-range-for-current-price"
        );

        FullOrder storage order = fullOrders[nextFullOrderId++];
        order.user = msg.sender;
        order.market = market;
        order.requestPrice = requestPrice;
        order.isStarted = true;
        order.sizeDelta = -request.sizeDelta;
        order.priceImpactDelta = request.priceImpactDelta;
        order.firstPairA = request.firstPairA;
        order.firstPairB = request.firstPairB;
        order.secondPairA = request.secondPairA;
        order.secondPairB = request.secondPairB;

        emit SubmitPairOrder(market, msg.sender, nextFullOrderId - 1, requestPrice, request);
    }

    function cancelFullOrder(uint256 orderId) external nonReentrant {
        FullOrder storage order = fullOrders[orderId];
        require(msg.sender == order.user, "unauthorized");

        order.isCancelled = true;

        emit CancelFullOrder(order.market, order.user, orderId);
    }

    function cancelPairOrder(uint256 orderId) external nonReentrant {
        FullOrder storage order = fullOrders[orderId];
        require(msg.sender == order.user, "unauthorized");

        order.isStarted = true;

        order.firstPairA = 0;
        order.firstPairB = 0;
        order.secondPairA = 0;
        order.secondPairB = 0;

        emit CancelPairOrder(order.market, order.user, orderId);
    }

    function cancelIndividualOrder(uint256 orderId, bool isFirst) external nonReentrant {
        FullOrder storage order = fullOrders[orderId];
        require(msg.sender == order.user, "unauthorized");

        if (isFirst) {
            order.firstPairA = 0;
            order.firstPairB = 0;
        } else {
            order.secondPairA = 0;
            order.secondPairB = 0;
        }

        emit CancelIndividualOrder(order.market, order.user, orderId, isFirst);
    }

    /// -----------------------------------------------------------------------
    /// Keeper Actions
    /// -----------------------------------------------------------------------

    function executeLimitOrder(uint256 orderId) external nonReentrant requiresAuth {
        FullOrder storage order = fullOrders[orderId];
        require(block.timestamp <= order.expiry, "order-expired");
        require(!order.isStarted, "order-executed");
        require(!order.isCancelled, "order-cancelled");

        (uint256 currentPrice, bool invalid) = IPerpMarket(order.market).assetPrice();
        require(!invalid && currentPrice != 0, "invalid-current-price");

        require(order.priceA >= currentPrice && order.priceB <= currentPrice, "not-in-range");

        uint256 dollarValue = _abs(order.sizeDelta).mulWadDown(currentPrice);
        uint256 totalFees = flatFee + dollarValue.mulWadDown(percentageFee);

        string[] memory targets = new string[](3);
        bytes[] memory datas = new bytes[](3);

        targets[0] = "Synthetix-Perp-v1";
        datas[0] = abi.encodeWithSignature(
            "trade(address,int256,uint256)", order.market, order.sizeDelta, order.priceImpactDelta
        );

        targets[1] = "Synthetix-Perp-v1";
        datas[1] =
            abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

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

        order.isStarted = true;

        emit ExecuteLimitOrder(order.market, order.user, orderId, currentPrice, totalFees);
    }

    function executePairOrder(uint256 orderId) external nonReentrant requiresAuth {
        FullOrder storage order = fullOrders[orderId];
        require(block.timestamp <= order.expiry, "order-expired");
        require(order.isStarted, "limit-order-not-executed-yet");
        require(!order.isCompleted, "pair-order-already-executed");
        require(!order.isCancelled, "order-cancelled");

        (uint256 currentPrice, bool invalid) = IPerpMarket(order.market).assetPrice();
        require(!invalid && currentPrice != 0, "invalid-current-price");

        bool isInFirstRange = currentPrice >= order.firstPairA && currentPrice <= order.firstPairB;
        bool isInSecondRange = currentPrice >= order.secondPairA && currentPrice <= order.secondPairB;

        require(isInFirstRange || isInSecondRange, "not-in-range");

        IPerpMarket.Position memory position = IPerpMarket(order.market).positions(order.user);

        if (_abs(order.sizeDelta) > _abs(position.size)) {
            order.sizeDelta = position.size;
        }

        uint256 dollarValue = _abs(order.sizeDelta).mulWadDown(currentPrice);
        uint256 totalFees = flatFee + dollarValue.mulWadDown(percentageFee);

        if (order.firstPairA > 0 && order.firstPairB > 0 && isInFirstRange) {
            string[] memory targets = new string[](3);
            bytes[] memory datas = new bytes[](3);

            targets[0] = "Synthetix-Perp-v1";
            datas[0] = abi.encodeWithSignature(
                "trade(address,int256,uint256)", order.market, -order.sizeDelta, order.priceImpactDelta
            );

            targets[1] = "Synthetix-Perp-v1";
            datas[1] =
                abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

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

            order.isCompleted = true;

            emit ExecutePairOrder(order.market, order.user, orderId, currentPrice, totalFees);

            return;
        }

        if (order.secondPairA > 0 && order.secondPairB > 0 && isInSecondRange) {
            string[] memory targets = new string[](3);
            bytes[] memory datas = new bytes[](3);

            targets[0] = "Synthetix-Perp-v1";
            datas[0] = abi.encodeWithSignature(
                "trade(address,int256,uint256)", order.market, -order.sizeDelta, order.priceImpactDelta
            );

            targets[1] = "Synthetix-Perp-v1";
            datas[1] =
                abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

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

            order.isCompleted = true;

            emit ExecutePairOrder(order.market, order.user, orderId, currentPrice, totalFees);

            return;
        }
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

    function updateFeeReceipient(address _feeReceipient) external requiresAuth {
        emit UpdateFeeReceipient(feeReceipient, _feeReceipient);

        feeReceipient = _feeReceipient;
    }

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

    /// @notice Emitted when fee receipient is updated
    /// @param oldReceipient Old Fee Receipient
    /// @param newReceipient New Fee Receipient
    event UpdateFeeReceipient(address oldReceipient, address newReceipient);

    /// @notice Emitted when fees are updated
    /// @param oldFlat Old flat fee rate
    /// @param newFlat New flat fee rate
    /// @param oldPercentage Old percentage fee rate
    /// @param newPercentage New percentage fee rate
    event UpdateFees(uint256 oldFlat, uint256 newFlat, uint256 oldPercentage, uint256 newPercentage);

    /// @notice Emitted when an order is submitted
    /// @param market Address of the perp market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param requestPrice Price of the asset at the time of request
    /// @param request Request Params
    event SubmitFullOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 requestPrice, FullOrderRequest request
    );

    /// @notice Emitted when an order is submitted
    /// @param market Address of the perp market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param requestPrice Price of the asset at the time of request
    /// @param request Request Params
    event SubmitPairOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 requestPrice, PairOrderRequest request
    );

    /// @notice Emitted when an order request is cancelled
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order ID
    event CancelFullOrder(address indexed market, address indexed user, uint256 orderId);

    /// @notice Emitted when a pair order request is cancelled
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order ID
    event CancelPairOrder(address indexed market, address indexed user, uint256 orderId);

    /// @notice Emitted when an individual order from paid order request is cancelled
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param isFirst Whether the individual order is the first one or second
    event CancelIndividualOrder(address indexed market, address indexed user, uint256 orderId, bool isFirst);

    /// @notice Emitted when a limit order is executed
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order id
    /// @param executionPrice Price at the time of execution
    /// @param totalFee Total fee deducted from margin
    event ExecuteLimitOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 executionPrice, uint256 totalFee
    );

    /// @notice Emitted when the pair order is executed
    /// @param market Address of the perp v2 market
    /// @param user Address of the user
    /// @param orderId Order id
    /// @param executionPrice Price at the time of execution
    /// @param totalFee Total fee deducted from margin
    event ExecutePairOrder(
        address indexed market, address indexed user, uint256 orderId, uint256 executionPrice, uint256 totalFee
    );
}
