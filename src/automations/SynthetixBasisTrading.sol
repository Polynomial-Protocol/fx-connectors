// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

interface IList {
    function accountID(address) external view returns (uint64);
}

interface IFuturesMarketManager {
    function marketForKey(bytes32 marketKey) external view returns (address);
}

interface IPerpMarket {
    function assetPrice() external view returns (uint256 price, bool invalid);
    function baseAsset() external view returns (bytes32 key);
}

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
}

interface ISynthetix {
    function exchangeOnBehalfWithTracking(
        address exchangeForAddress,
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint256 amountReceived);
}

contract SynthetixBasisTrading is Auth, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;

    struct Order {
        bytes32 synthKey;
        address market;
        address user;
        uint256 amt;
        uint256 requestTime;
        uint256 priceImpactDelta;
        bool isExecuted;
    }

    /// @notice Futures Market Manager
    IFuturesMarketManager public constant marketManager =
        IFuturesMarketManager(0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e);

    /// @notice Synthetix
    ISynthetix public constant synthetix = ISynthetix(0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4);

    /// @notice Min delay b/w request and execution
    uint256 public minDelay = 60;

    /// @notice Next order id
    uint256 public nextOrderId = 1;

    /// @notice Order id to order info mapping
    mapping(uint256 => Order) orders;

    constructor() Auth(msg.sender, Authority(address(0x0))) {}

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function submitOrder(bytes32 marketKey, uint256 amt, uint256 priceImpactDelta) external nonReentrant {
        require(isAllowed());

        IPerpMarket perpMarket = IPerpMarket(marketManager.marketForKey(marketKey));

        (uint256 requestPrice, bool invalid) = perpMarket.assetPrice();
        require(!invalid);

        bytes32 synthKey = perpMarket.baseAsset();

        Order storage order = orders[nextOrderId++];

        order.synthKey = synthKey;
        order.market = address(perpMarket);
        order.user = msg.sender;
        order.amt = amt;
        order.requestTime = block.timestamp;
        order.priceImpactDelta = priceImpactDelta;

        emit SubmitOrder(synthKey, msg.sender, nextOrderId - 1, amt, requestPrice);
    }

    /// -----------------------------------------------------------------------
    /// Keeper Actions
    /// -----------------------------------------------------------------------

    function executeOrder(uint256 orderId) external nonReentrant requiresAuth {
        Order storage order = orders[orderId];
        require(block.timestamp >= order.requestTime + minDelay && !order.isExecuted);

        (uint256 currentPrice, bool invalid) = IPerpMarket(order.market).assetPrice();
        require(!invalid);

        string[] memory targets = new string[](1);
        bytes[] memory datas = new bytes[](1);

        targets[0] = "Synthetix-Perp-v1";
        datas[0] =
            abi.encodeWithSignature("removeMargin(address,uint256,uint256,uint256)", order.market, order.amt, 0, 0);

        IAccount(order.user).cast(targets, datas, address(0x0));

        uint256 baseReceived = synthetix.exchangeOnBehalfWithTracking(
            order.user, "sUSD", order.amt, order.synthKey, 0x7cb6bF3e7395965b2162A7C2e6876720C20012d6, "polynomial"
        );
        int256 sizeDelta = -int256(baseReceived);

        targets = new string[](1);
        datas = new bytes[](1);

        targets[0] = "Synthetix-Perp-v1";
        datas[0] =
            abi.encodeWithSignature("trade(address,int256,uint256)", order.market, sizeDelta, order.priceImpactDelta);

        IAccount(order.user).cast(targets, datas, address(0x0));

        emit ExecuteOrder(order.synthKey, order.user, orderId, currentPrice, baseReceived);

        order.isExecuted = true;
    }

    /// -----------------------------------------------------------------------
    /// Internals
    /// -----------------------------------------------------------------------

    /// @notice Returns whether an address is a SCW or not
    function isAllowed() internal view returns (bool) {
        return IList(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B).accountID(msg.sender) != 0;
    }

    /// -----------------------------------------------------------------------
    /// Admin Actions
    /// -----------------------------------------------------------------------

    function setMinDelay(uint256 delay) external requiresAuth {
        require(delay >= 60);
        emit SetMinDelay(minDelay, delay);
        minDelay = delay;
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when min delay is updated
    /// @param oldDelay old delay
    /// @param newDelay new delay
    event SetMinDelay(uint256 oldDelay, uint256 newDelay);

    /// @notice Emitted when the order is submitted
    /// @param synthKey Synth key to execute the order on
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param amt Amount sUSD to convert to synth
    /// @param requestPrice Price of base asset at the time of submission
    event SubmitOrder(
        bytes32 indexed synthKey, address indexed user, uint256 orderId, uint256 amt, uint256 requestPrice
    );

    /// @notice Emitted when the order is executed
    /// @param synthKey Synth key to execute the order on
    /// @param user Address of the user
    /// @param orderId Order ID
    /// @param executionPrice Price at the time of execution
    /// @param baseReceived Amount base received from exchange
    event ExecuteOrder(
        bytes32 indexed synthKey, address indexed user, uint256 orderId, uint256 executionPrice, uint256 baseReceived
    );
}
