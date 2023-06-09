// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";
import {ReentrancyGuardUpgradable} from "../libraries/ReentracyUpgradable.sol";

import {IPyth} from "../interfaces/IPyth.sol";

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

    /// @notice Pyth Oracle
    IPyth public pyth;

    /// @notice Address of the fee receipient
    address public feeReceipient;

    /// @notice Flat fee charged per each order, taken from margin upon execution
    uint256 public flatFee;

    /// @notice Percentage fee charged per each order (or dollar value)
    uint256 public percentageFee;

    /// @notice Next full order id
    uint256 public nextFullOrderId;

    /// @notice Time Cutoff for Pyth Price
    uint256 public pythPriceTimeCutoff;

    /// @notice Price Delta Cutoff for Pyth Price
    uint256 public pythPriceDeltaCutoff;

    /// @notice Storage gap
    uint256[50] private _gap;

    /// @notice Order id to order info mapping
    mapping(uint256 => FullOrder) private fullOrders;

    /// @notice Pyth Oracle IDs to read for each market
    mapping(address => bytes32) public pythIds;

    function initialize(IPyth _pyth, address _owner, address _feeReceipient, uint256 _flatFee, uint256 _percentageFee)
        public
        initializer
    {
        _auth_init(_owner, Authority(address(0x0)));
        _reentrancy_init();

        emit UpdateFeeReceipient(feeReceipient, _feeReceipient);
        emit UpdateFees(flatFee, _flatFee, percentageFee, _percentageFee);

        pyth = _pyth;

        feeReceipient = _feeReceipient;

        flatFee = _flatFee;
        percentageFee = _percentageFee;

        nextFullOrderId = 1;
    }

    /// -----------------------------------------------------------------------
    /// Views
    /// -----------------------------------------------------------------------

    function getSafePrice(address market) public view returns (uint256) {
        (uint256 clPrice, bool invalid) = IPerpMarket(market).assetPrice();
        if (invalid) return 0;

        IPyth.Price memory pythData = pyth.getPriceUnsafe(pythIds[market]);
        uint256 pythPrice = _getWadPrice(pythData.price, pythData.expo);

        uint256 priceDelta = pythPrice > clPrice
            ? (pythPrice - clPrice).divWadDown(clPrice)
            : (clPrice - pythPrice).divWadDown(pythPrice);

        bool isPythPriceStale = pythData.price <= 0 || block.timestamp - pythData.publishTime > pythPriceTimeCutoff
            || priceDelta > pythPriceDeltaCutoff;

        if (isPythPriceStale) {
            return clPrice;
        }

        return pythPrice;
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function submitFullOrder(address market, FullOrderRequest memory request) external nonReentrant {
        require(isAllowed());
        require(request.expiry > block.timestamp, "invalid-expiry");

        uint256 requestPrice = getSafePrice(market);
        require(requestPrice != 0, "invalid-current-price");

        require(request.priceA != 0 && request.priceB != 0, "range-is-zero");
        require(request.priceB > request.priceA, "invalid-range");
        require(request.priceA > requestPrice || request.priceB < requestPrice, "invalid-range-for-current-price");

        FullOrder storage order = fullOrders[nextFullOrderId++];

        order.user = msg.sender;
        order.market = market;
        order.expiry = request.expiry;
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

        uint256 requestPrice = getSafePrice(market);
        require(requestPrice != 0, "invalid-current-price");

        require(request.firstPairA != 0 && request.firstPairA != 0, "range-is-zero");
        require(request.firstPairB > request.firstPairA, "invalid-range");
        require(
            request.firstPairA > requestPrice || request.firstPairB < requestPrice, "invalid-range-for-current-price"
        );

        FullOrder storage order = fullOrders[nextFullOrderId++];

        order.user = msg.sender;
        order.market = market;
        order.expiry = request.expiry;
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

    function addPairOrder(uint256 id, PairOrderRequest memory request) external nonReentrant {
        FullOrder storage order = fullOrders[id];
        require(msg.sender == order.user);
        require(!order.isCancelled, "order-already-cancelled");
        require(!order.isCompleted, "order-already-completed");
        require(request.expiry > block.timestamp, "invalid-expiry");

        uint256 requestPrice = getSafePrice(order.market);
        require(requestPrice != 0, "invalid-current-price");

        require(request.firstPairA != 0 && request.firstPairA != 0, "range-is-zero");
        require(request.firstPairB > request.firstPairA, "invalid-range");
        require(
            request.firstPairA > requestPrice || request.firstPairB < requestPrice, "invalid-range-for-current-price"
        );

        order.firstPairA = request.firstPairA;
        order.firstPairB = request.firstPairB;
        order.secondPairA = request.secondPairA;
        order.secondPairB = request.secondPairB;
        order.expiry = request.expiry;

        emit AddPairOrder(order.market, msg.sender, id, requestPrice, request);
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
    /// Views
    /// -----------------------------------------------------------------------

    function getFullOrder(uint256 id) external view returns (FullOrder memory order) {
        order = fullOrders[id];
    }

    /// -----------------------------------------------------------------------
    /// Keeper Actions
    /// -----------------------------------------------------------------------

    function updateAndExecuteLimitOrder(bytes[] calldata updateData, uint256 orderId) external payable requiresAuth {
        pyth.updatePriceFeeds{value: msg.value}(updateData);
        executeLimitOrder(orderId);
    }

    function updateAndExecutePairOrder(bytes[] calldata updateData, uint256 orderId) external payable requiresAuth {
        pyth.updatePriceFeeds{value: msg.value}(updateData);
        executePairOrder(orderId);
    }

    function executeMultiple(uint256[] memory limitOrders, uint256[] memory pairOrders) external requiresAuth {
        for (uint256 i = 0; i < limitOrders.length; i++) {
            executeLimitOrder(limitOrders[i]);
        }

        for (uint256 i = 0; i < pairOrders.length; i++) {
            executePairOrder(pairOrders[i]);
        }
    }

    function executeLimitOrder(uint256 orderId) public nonReentrant requiresAuth {
        FullOrder storage order = fullOrders[orderId];
        require(block.timestamp <= order.expiry, "order-expired");
        require(!order.isStarted, "order-executed");
        require(!order.isCancelled, "order-cancelled");

        (bool isInRange, uint256 currentPrice,) = isInPriceRange(order, true);
        require(isInRange, "price-not-in-range");

        uint256 dollarValue = _abs(order.sizeDelta).mulWadDown(currentPrice);
        uint256 totalFees = flatFee + dollarValue.mulWadDown(percentageFee);

        string[] memory targets = new string[](3);
        bytes[] memory datas = new bytes[](3);

        targets[0] = "Synthetix-Perp-v1.3";
        datas[0] =
            abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

        targets[1] = "Synthetix-Perp-v1.3";
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

        order.isStarted = true;

        emit ExecuteLimitOrder(order.market, order.user, orderId, currentPrice, totalFees);
    }

    function executePairOrder(uint256 orderId) public nonReentrant requiresAuth {
        FullOrder storage order = fullOrders[orderId];
        require(block.timestamp <= order.expiry, "order-expired");
        require(order.isStarted, "limit-order-not-executed-yet");
        require(!order.isCompleted, "pair-order-already-executed");
        require(!order.isCancelled, "order-cancelled");

        (bool isInRange, uint256 currentPrice, bool isInFirstRange) = isInPriceRange(order, false);
        require(isInRange, "price-not-in-range");

        IPerpMarket.Position memory position = IPerpMarket(order.market).positions(order.user);

        if (_abs(order.sizeDelta) > _abs(position.size)) {
            order.sizeDelta = position.size;
        }

        if (order.firstPairA > 0 && order.firstPairB > 0 && isInFirstRange) {
            _executePairOrder(order, orderId, currentPrice);

            return;
        }

        if (order.secondPairA > 0 && order.secondPairB > 0 && !isInFirstRange) {
            _executePairOrder(order, orderId, currentPrice);

            return;
        }
    }

    function _executePairOrder(FullOrder memory order, uint256 orderId, uint256 currentPrice) internal {
        uint256 dollarValue = _abs(order.sizeDelta).mulWadDown(currentPrice);
        uint256 totalFees = flatFee + dollarValue.mulWadDown(percentageFee);

        string[] memory targets = new string[](3);
        bytes[] memory datas = new bytes[](3);

        targets[0] = "Synthetix-Perp-v1.3";
        datas[0] =
            abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, totalFees, 0, 0);

        targets[1] = "Synthetix-Perp-v1.3";
        datas[1] = abi.encodeWithSignature(
            "trade(address,int256,uint256)", order.market, -order.sizeDelta, order.priceImpactDelta
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

        order.isCompleted = true;

        emit ExecutePairOrder(order.market, order.user, orderId, currentPrice, totalFees);
    }

    receive() external payable {
        (bool success,) = feeReceipient.call{value: msg.value}("");
        require(success);

        emit ReceiveEther(msg.sender, msg.value);
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

    /// @notice Returns whether an order can be executed or not based on current price
    /// @param order Order struct
    /// @param isFirst Whether the request is for the first order or pair order
    function isInPriceRange(FullOrder memory order, bool isFirst) internal view returns (bool, uint256, bool) {
        uint256 safePrice = getSafePrice(order.market);

        if (isFirst && order.priceA >= safePrice && order.priceB <= safePrice) {
            return (true, safePrice, false);
        } else {
            bool isInFirstRange = safePrice >= order.firstPairA && safePrice <= order.firstPairB;
            bool isInSecondRange = safePrice >= order.secondPairA && safePrice <= order.secondPairB;

            if (isInFirstRange || isInSecondRange) {
                return (true, safePrice, isInFirstRange);
            }
        }

        return (false, safePrice, false);
    }

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

    function _getWadPrice(int64 price, int32 expo) internal pure returns (uint256 wadPrice) {
        uint256 exponent = _abs(expo);
        uint256 lastPrice = _abs(price);

        if (exponent >= 18) {
            uint256 denom = 10 ** (exponent - 18);
            wadPrice = lastPrice / denom;
        } else {
            uint256 multiplier = 10 ** (18 - exponent);
            wadPrice = lastPrice * multiplier;
        }
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

    /// @notice Update Pyth Oracle ID
    /// @param market Address of the market
    /// @param id New Pyth Oracle ID
    function updatePythOracleId(address market, bytes32 id) external requiresAuth {
        emit UpdatePythId(market, pythIds[market], id);

        pythIds[market] = id;
    }

    /// @notice Update Pyth Oracle IDs
    /// @param markets Market addresses
    /// @param ids Pyth Oracle IDs
    function updatePythOracleIds(address[] memory markets, bytes32[] memory ids) external requiresAuth {
        require(markets.length == ids.length);
        for (uint256 i = 0; i < markets.length; i++) {
            emit UpdatePythId(markets[i], pythIds[markets[i]], ids[i]);

            pythIds[markets[i]] = ids[i];
        }
    }

    /// @notice Update Pyth Time Cutoff
    /// @param newCutoff New cutoff
    function updatePythTimeCutoff(uint256 newCutoff) external requiresAuth {
        emit UpdatePythTimeCutoff(pythPriceTimeCutoff, newCutoff);

        pythPriceTimeCutoff = newCutoff;
    }

    function updatePythDeltaCutoff(uint256 newCutoff) external requiresAuth {
        emit UpdatePythDeltaCutoff(pythPriceDeltaCutoff, newCutoff);

        pythPriceDeltaCutoff = newCutoff;
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

    /// @notice Emitted when Pyth oracle IDs are updated
    /// @param market Address of the market
    /// @param oldId Old Pyth Oracle ID
    /// @param newId New Pyth Oracle ID
    event UpdatePythId(address indexed market, bytes32 oldId, bytes32 newId);

    /// @notice Emitted when Pyth price time cutoff is updated
    /// @param oldCutoff Old cutoff
    /// @param newCutoff New cutoff
    event UpdatePythTimeCutoff(uint256 oldCutoff, uint256 newCutoff);

    /// @notice Emitted when Pyth price delta cutoff is updated
    /// @param oldCutoff Old Cutoff
    /// @param newCutoff New Cutoff
    event UpdatePythDeltaCutoff(uint256 oldCutoff, uint256 newCutoff);

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

    /// @notice Emitted when an pair order is added to an existing full order
    /// @param market Address of the perp market
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param requestPrice Price of the asset at the time of request
    /// @param request Request Params
    event AddPairOrder(
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

    /// @notice Emitted when ether is received
    event ReceiveEther(address indexed from, uint256 amt);
}
