// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";
import {
    SynthetixTwapOrdersV3,
    IList,
    IPythNode,
    IPyth,
    IPerpMarket,
    IAccount
} from "../src/common/automations/SynthetixTwapOrdersV3.sol";
import {MockIList, MockIPyth, MockIPythNode, MockIPerpMarket, MockIAccount} from "./mocks/mocks.sol";

contract SynthetixTwapOrdersV3Test is Test {
    /// -----------------------------------------------------------------------
    /// constants and variables
    /// -----------------------------------------------------------------------

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant ORDER_REQUEST_TYPEHASH = keccak256(
        "OrderRequest(address user,uint128 accountId,uint128 marketId,int128 lotSize,uint128 startTime,uint128 interval,uint128 totalIterations,uint128 acceptableDeviation,uint128 slippage)"
    );
    bytes32 DOMAIN_SEPARATOR;

    SynthetixTwapOrdersV3 synthetixTwapOrders;
    address owner;
    address user;
    uint256 userKey;
    address someone;

    IList list;
    MockIPythNode pythnode;
    IPyth pyth;
    MockIPerpMarket perpMarket;
    MockIAccount account; //scw
    SynthetixTwapOrdersV3.OrderRequest req;
    bytes sig;

    uint128 accountId = 11;
    uint128 marketId = 22;
    int128 lotSize = 10;
    uint128 startTime = 50000;
    uint128 interval = 20000;
    uint128 totalIterations = 3;
    uint128 acceptableDeviation = 100;
    uint128 slippage = 0.1 ether;

    SynthetixTwapOrdersV3.OrderRecord record;

    /// -----------------------------------------------------------------------
    /// setUp
    /// -----------------------------------------------------------------------

    function setUp() external {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes("Polynomial Twap Orders")),
                keccak256(bytes("3")),
                block.chainid,
                address(this)
            )
        );

        // Contracts and addresses

        synthetixTwapOrders = new SynthetixTwapOrdersV3();
        owner = makeAddr("Owner");
        (user, userKey) = makeAddrAndKey("User");
        someone = makeAddr("Someone");

        // mocks

        list = new MockIList();
        pyth = new MockIPyth();
        pythnode = new MockIPythNode(pyth);
        perpMarket = new MockIPerpMarket();
        account = new MockIAccount();

        // setups
        pythnode.setLatestPrice(5 ether);
        req = SynthetixTwapOrdersV3.OrderRequest(
            address(account),
            accountId,
            marketId,
            lotSize,
            startTime,
            interval,
            totalIterations,
            acceptableDeviation,
            slippage
        );
        sig = computeOrderRequestSign(req, userKey);

        synthetixTwapOrders.initialize(owner, address(list), address(pythnode), address(perpMarket));
    }

    /// -----------------------------------------------------------------------
    /// Helpers
    /// -----------------------------------------------------------------------

    function computeOrderRequestSign(SynthetixTwapOrdersV3.OrderRequest memory request, uint256 privateKey)
        public
        view
        returns (bytes memory)
    {
        bytes32 reqHash = keccak256(
            abi.encode(
                ORDER_REQUEST_TYPEHASH,
                request.user,
                request.accountId,
                request.marketId,
                request.lotSize,
                request.startTime,
                request.interval,
                request.totalIterations,
                request.acceptableDeviation,
                request.slippage
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, reqHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function getCommitTradeHash(uint128 accId, uint128 _marketId, int128 _size, uint256 accPrice)
        public
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature("commitTrade(uint128,uint128,int128,uint256)", accId, _marketId, _size, accPrice);
    }

    function setTwapReq(
        int128 _lotSize,
        uint128 _startTime,
        uint128 _interval,
        uint128 _totalIterations,
        uint128 _acceptableDeviation,
        uint128 _slippage
    ) internal {
        req.lotSize = _lotSize;
        req.startTime = _startTime;
        req.interval = _interval;
        req.totalIterations = _totalIterations;
        req.acceptableDeviation = _acceptableDeviation;
        req.slippage = _slippage;

        sig = computeOrderRequestSign(req, userKey);
    }

    function executeInitialLot(bool onchain) internal {
        if (onchain) {
            vm.prank(address(account));
            synthetixTwapOrders.placeOrder(req);
        } else {
            vm.prank(someone);
            synthetixTwapOrders.executeOrder(req, sig);
        }
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Test - Initialize
    /// -----------------------------------------------------------------------

    function test_cannotInitializeTwice() external {
        vm.expectRevert();
        synthetixTwapOrders.initialize(owner, address(list), address(pythnode), address(perpMarket));
    }

    /// -----------------------------------------------------------------------
    /// Test - Cancel Order (offchain)
    /// -----------------------------------------------------------------------

    function test_cancelOrderOffChain_byNonSigner() external {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.NotAuthorized.selector, user, someone));
        synthetixTwapOrders.cancelOrder(req, sig);
    }

    function test_cancelOrderOffChain_success() external {
        vm.prank(user);
        synthetixTwapOrders.cancelOrder(req, sig);

        assertEq(synthetixTwapOrders.cancelledHashes(keccak256(sig)), true);
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute Order (offchain)
    /// -----------------------------------------------------------------------

    function test_executeOrderOffChain_withInvalidTotalIterations() external {
        setTwapReq(lotSize, startTime, interval, 0, acceptableDeviation, slippage);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.InvalidOrder.selector, req));
        synthetixTwapOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withCancelledSig() external {
        setTwapReq(lotSize, startTime, interval, startTime, acceptableDeviation, slippage);

        vm.prank(user);
        synthetixTwapOrders.cancelOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixTwapOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withSubmittedSig() external {
        setTwapReq(lotSize, startTime, interval, startTime, acceptableDeviation, slippage);
        vm.warp(startTime);

        vm.prank(someone);
        synthetixTwapOrders.executeOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixTwapOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withUnacceptableDeviation() external {
        setTwapReq(lotSize, startTime, interval, startTime, acceptableDeviation, slippage);

        /// @dev too early
        uint256 blockTimestamp = startTime - acceptableDeviation - 1;
        vm.warp(blockTimestamp);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixTwapOrdersV3.UnacceptableTimeDeviation.selector, startTime, acceptableDeviation, blockTimestamp
            )
        );
        synthetixTwapOrders.executeOrder(req, sig);

        /// @dev too late
        blockTimestamp = startTime + acceptableDeviation + 1;
        vm.warp(blockTimestamp);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixTwapOrdersV3.UnacceptableTimeDeviation.selector, startTime, acceptableDeviation, blockTimestamp
            )
        );
        synthetixTwapOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_successWithinAcceptableDeviation() external {
        uint256[3] memory timestamps;
        timestamps[0] = startTime;
        timestamps[1] = startTime - acceptableDeviation;
        timestamps[2] = startTime + acceptableDeviation;

        for (uint128 index = 0; index < timestamps.length; index++) {
            setTwapReq(lotSize + int128(index), startTime, interval, totalIterations, acceptableDeviation, slippage);
            uint256 blockTimestamp = timestamps[index];
            vm.warp(blockTimestamp);

            vm.prank(someone);
            synthetixTwapOrders.executeOrder(req, sig);

            assertEq(synthetixTwapOrders.nextOrderId(), index + 2);
            assertEq(synthetixTwapOrders.submittedHashes(keccak256(sig)), true);

            /// @dev check record
            (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) =
                synthetixTwapOrders.records(index + 1);
            assert(record.status == SynthetixTwapOrdersV3.OrderStatus.EXECUTING);
            assertEq(record.lastExecutionTimestamp, blockTimestamp);
            assertEq(record.iterationsCompleted, 1);
        }
    }

    function test_executeOrderOffChain_withCompletedIterations() external {
        setTwapReq(lotSize, startTime, interval, 1, acceptableDeviation, slippage);
        uint256 blockTimestamp = startTime;
        vm.warp(blockTimestamp);

        vm.prank(someone);
        synthetixTwapOrders.executeOrder(req, sig);

        assertEq(synthetixTwapOrders.nextOrderId(), 2);
        assertEq(synthetixTwapOrders.submittedHashes(keccak256(sig)), true);

        /// @dev check record
        (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.COMPLETED);
        assertEq(record.lastExecutionTimestamp, blockTimestamp);
        assertEq(record.iterationsCompleted, 1);
    }

    function test_executeOrderOffChain_castValues() external {
        uint256 blockTimestamp = startTime;
        vm.warp(blockTimestamp);

        /// @dev positive lot size
        setTwapReq(lotSize, startTime, interval, totalIterations, acceptableDeviation, slippage);
        vm.prank(someone);
        synthetixTwapOrders.executeOrder(req, sig);

        assertEq(synthetixTwapOrders.nextOrderId(), 2);
        assertEq(account.data(), getCommitTradeHash(accountId, marketId, lotSize, 5.5 ether));

        /// @dev negative lot size
        setTwapReq(-lotSize, startTime, interval, totalIterations, acceptableDeviation, slippage);
        vm.prank(someone);
        synthetixTwapOrders.executeOrder(req, sig);

        assertEq(synthetixTwapOrders.nextOrderId(), 3);
        assertEq(account.data(), getCommitTradeHash(accountId, marketId, -lotSize, 4.5 ether));
    }

    /// -----------------------------------------------------------------------
    /// Test - Place Order (onchain)
    /// -----------------------------------------------------------------------

    function test_placeOrder_withNonzeroStartTime() external {
        setTwapReq(lotSize, startTime, interval, totalIterations, acceptableDeviation, slippage);

        vm.prank(address(account));
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.InvalidOrder.selector, req));
        synthetixTwapOrders.placeOrder(req);
    }

    function test_placeOrder_withZeroIterations() external {
        setTwapReq(lotSize, 0, interval, 0, acceptableDeviation, slippage);

        vm.prank(address(account));
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.InvalidOrder.selector, req));
        synthetixTwapOrders.placeOrder(req);
    }

    function test_placeOrder_succesful() external {
        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);

        vm.warp(startTime);

        vm.prank(address(account));
        synthetixTwapOrders.placeOrder(req);

        assertEq(synthetixTwapOrders.nextOrderId(), 2);

        /// @dev check record
        (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.EXECUTING);
        assertEq(record.lastExecutionTimestamp, startTime);
        assertEq(record.iterationsCompleted, 1);
    }

    function test_placeOrder_withCompletedIterations() external {
        setTwapReq(lotSize, 0, interval, 1, acceptableDeviation, slippage);

        vm.warp(startTime);

        vm.prank(address(account));
        synthetixTwapOrders.placeOrder(req);

        assertEq(synthetixTwapOrders.nextOrderId(), 2);

        /// @dev check record
        (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.COMPLETED);
        assertEq(record.lastExecutionTimestamp, startTime);
        assertEq(record.iterationsCompleted, 1);
    }

    function test_placeOrder_castValues() external {
        vm.warp(startTime);

        /// @dev positive lot size
        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);
        vm.prank(address(account));
        synthetixTwapOrders.placeOrder(req);

        assertEq(synthetixTwapOrders.nextOrderId(), 2);
        assertEq(account.data(), getCommitTradeHash(accountId, marketId, lotSize, 5.5 ether));

        /// @dev negative lot size
        setTwapReq(-lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);
        vm.prank(address(account));
        synthetixTwapOrders.placeOrder(req);

        assertEq(synthetixTwapOrders.nextOrderId(), 3);
        assertEq(account.data(), getCommitTradeHash(accountId, marketId, -lotSize, 4.5 ether));
    }

    /// -----------------------------------------------------------------------
    /// Test - Cancel order (onchain)
    /// -----------------------------------------------------------------------

    function test_cancelOrderOnChain_byNonUser() external {
        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);

        executeInitialLot(true);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.NotAuthorized.selector, address(account), someone));
        synthetixTwapOrders.cancelOrder(1);
    }

    function test_cancelOrderOnChain_successWithOnChainOrder() external {
        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);

        executeInitialLot(true);

        vm.prank(address(account));
        synthetixTwapOrders.cancelOrder(1);

        (record.status,,) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.CANCELLED);
    }

    function test_cancelOrderOnChain_successWithOffChainOrder() external {
        setTwapReq(lotSize, startTime, interval, totalIterations, acceptableDeviation, slippage);
        vm.warp(startTime);

        executeInitialLot(false);

        vm.prank(address(account));
        synthetixTwapOrders.cancelOrder(1);

        (record.status,,) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.CANCELLED);
    }

    /// -----------------------------------------------------------------------
    /// Test - ExecuteOrder (onchain)
    /// -----------------------------------------------------------------------

    function test_executeOrderOnChain_withCompletedOrder() external {
        setTwapReq(lotSize, 0, interval, 1, acceptableDeviation, slippage);

        executeInitialLot(true);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.OrderCompleted.selector, 1));
        synthetixTwapOrders.executeOrder(1);
    }

    function test_executeOrderOnChain_withCanelledOrder() external {
        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);

        executeInitialLot(true);

        vm.prank(address(account));
        synthetixTwapOrders.cancelOrder(1);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixTwapOrdersV3.OrderCancelled.selector, 1));
        synthetixTwapOrders.executeOrder(1);
    }

    function test_executeOrderOnChain_withUnacceptableDeviation() external {
        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);
        vm.warp(startTime);

        executeInitialLot(true);

        uint256 blockTimestamp = startTime + interval - acceptableDeviation - 1;
        vm.warp(blockTimestamp);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixTwapOrdersV3.UnacceptableTimeDeviation.selector,
                startTime + interval,
                acceptableDeviation,
                blockTimestamp
            )
        );
        synthetixTwapOrders.executeOrder(1);

        blockTimestamp = startTime + interval + acceptableDeviation + 1;
        vm.warp(blockTimestamp);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixTwapOrdersV3.UnacceptableTimeDeviation.selector,
                startTime + interval,
                acceptableDeviation,
                blockTimestamp
            )
        );
        synthetixTwapOrders.executeOrder(1);
    }

    function test_executeOrderOnChain_onChainCyle() external {
        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);

        vm.warp(startTime);
        executeInitialLot(true);

        vm.warp(startTime + interval);
        vm.prank(someone);
        synthetixTwapOrders.executeOrder(1);

        (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.EXECUTING);
        assertEq(record.lastExecutionTimestamp, startTime + interval);
        assertEq(record.iterationsCompleted, 2);

        vm.warp(startTime + 2 * interval);
        vm.prank(someone);
        synthetixTwapOrders.executeOrder(1);

        (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.COMPLETED);
        assertEq(record.lastExecutionTimestamp, startTime + 2 * interval);
        assertEq(record.iterationsCompleted, 3);
    }

    function test_executeOrderOnChain_offChainCyle() external {
        setTwapReq(lotSize, startTime, interval, totalIterations, acceptableDeviation, slippage);

        vm.warp(startTime);
        executeInitialLot(false);

        vm.warp(startTime + interval);
        vm.prank(someone);
        synthetixTwapOrders.executeOrder(1);

        (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.EXECUTING);
        assertEq(record.lastExecutionTimestamp, startTime + interval);
        assertEq(record.iterationsCompleted, 2);

        vm.warp(startTime + 2 * interval);
        vm.prank(someone);
        synthetixTwapOrders.executeOrder(1);

        (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) = synthetixTwapOrders.records(1);
        assert(record.status == SynthetixTwapOrdersV3.OrderStatus.COMPLETED);
        assertEq(record.lastExecutionTimestamp, startTime + 2 * interval);
        assertEq(record.iterationsCompleted, 3);
    }

    function test_executeOrderOnChain_withAcceptableDeviation() external {
        uint256[3] memory timestamps;
        timestamps[0] = startTime + interval;
        timestamps[1] = startTime + interval - acceptableDeviation;
        timestamps[2] = startTime + interval + acceptableDeviation;

        for (uint128 index = 0; index < timestamps.length; index++) {
            setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);
            vm.warp(startTime);

            executeInitialLot(true);

            uint256 blockTimestamp = timestamps[index];
            vm.warp(blockTimestamp);
            vm.prank(someone);
            synthetixTwapOrders.executeOrder(index + 1);

            (record.status, record.lastExecutionTimestamp, record.iterationsCompleted) =
                synthetixTwapOrders.records(index + 1);
            assert(record.status == SynthetixTwapOrdersV3.OrderStatus.EXECUTING);
            assertEq(record.lastExecutionTimestamp, blockTimestamp);
            assertEq(record.iterationsCompleted, 2);
        }
    }

    function test_executeOrderOnChain_castValues() external {
        vm.warp(startTime);

        setTwapReq(lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);
        executeInitialLot(true);

        setTwapReq(-lotSize, 0, interval, totalIterations, acceptableDeviation, slippage);
        executeInitialLot(true);

        uint256 blockTimestamp = startTime + interval;
        vm.warp(blockTimestamp);

        vm.prank(someone);
        synthetixTwapOrders.executeOrder(1);
        assertEq(account.data(), getCommitTradeHash(accountId, marketId, lotSize, 5.5 ether));

        vm.prank(someone);
        synthetixTwapOrders.executeOrder(2);
        assertEq(account.data(), getCommitTradeHash(accountId, marketId, -lotSize, 4.5 ether));
    }
}
