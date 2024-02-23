// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";
import {
    SynthetixLimitOrdersV3,
    IList,
    IPythNode,
    IPyth,
    IPerpMarket,
    IAccount
} from "../src/common/automations/SynthetixLimitOrdersV3.sol";
import {MockIList, MockIPyth, MockIPythNode, MockIPerpMarket, MockIAccount} from "./mocks/mocks.sol";

contract SynthetixLimitOrdersV3Test is Test {
    /// -----------------------------------------------------------------------
    /// constants and variables
    /// -----------------------------------------------------------------------

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant PRICE_RANGE_TYPEHASH =
        keccak256("PriceRange(uint256 priceA,uint256 priceB,uint256 acceptablePrice)");
    bytes32 constant ORDER_REQUEST_TYPEHASH = keccak256(
        "OrderRequest(address user,PriceRange price,PriceRange tpPrice,PriceRange slPrice,uint128 accountId,uint128 marketId,int128 size,uint128 expiry)"
    );
    bytes32 DOMAIN_SEPARATOR;

    SynthetixLimitOrdersV3 synthetixLimitOrders;
    address owner;
    address user;
    uint256 userKey;
    address someone;

    IList list;
    MockIPythNode pythnode;
    IPyth pyth;
    MockIPerpMarket perpMarket;
    MockIAccount account; //scw
    SynthetixLimitOrdersV3.OrderRequest req;
    bytes sig;

    uint128 expiry = 100;
    uint128 accountId = 11;
    uint128 marketId = 22;
    int128 size = 33;

    /// -----------------------------------------------------------------------
    /// setUp
    /// -----------------------------------------------------------------------

    function setUp() external {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes("Polynomial Limit Orders")),
                keccak256(bytes("3")),
                block.chainid,
                address(this)
            )
        );

        // Contracts and addresses

        synthetixLimitOrders = new SynthetixLimitOrdersV3();
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

        SynthetixLimitOrdersV3.PriceRange memory range = SynthetixLimitOrdersV3.PriceRange(0, 0, 0);
        pythnode.setLatestPrice(50);
        perpMarket.setOpenPosition(40);
        req = SynthetixLimitOrdersV3.OrderRequest(
            address(account), range, range, range, accountId, marketId, size, expiry
        );
        sig = computeOrderRequestSign(req, userKey);

        synthetixLimitOrders.initialize(owner, address(list), address(pythnode), address(perpMarket));
    }

    /// -----------------------------------------------------------------------
    /// Helpers
    /// -----------------------------------------------------------------------

    function computeOrderRequestSign(SynthetixLimitOrdersV3.OrderRequest memory request, uint256 privateKey)
        public
        view
        returns (bytes memory)
    {
        bytes32 priceHash = keccak256(
            abi.encode(PRICE_RANGE_TYPEHASH, request.price.priceA, request.price.priceB, request.price.acceptablePrice)
        );
        bytes32 tpPriceHash = keccak256(
            abi.encode(
                PRICE_RANGE_TYPEHASH, request.tpPrice.priceA, request.tpPrice.priceB, request.tpPrice.acceptablePrice
            )
        );
        bytes32 slPriceHash = keccak256(
            abi.encode(
                PRICE_RANGE_TYPEHASH, request.slPrice.priceA, request.slPrice.priceB, request.slPrice.acceptablePrice
            )
        );
        bytes32 reqHash = keccak256(
            abi.encode(
                ORDER_REQUEST_TYPEHASH,
                request.user,
                priceHash,
                tpPriceHash,
                slPriceHash,
                request.accountId,
                request.marketId,
                request.size,
                request.expiry
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

    function setPrices(uint256 priceA, uint256 priceB, uint256 latestPrice) internal {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        pythnode.setLatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, userKey);
    }

    function setTpPrices(uint256 priceA, uint256 priceB, uint256 tpPriceA, uint256 tpPriceB, uint256 latestPrice)
        internal
    {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        req.tpPrice.priceA = tpPriceA;
        req.tpPrice.priceB = tpPriceB;
        pythnode.setLatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, userKey);
    }

    function setSlPrices(uint256 priceA, uint256 priceB, uint256 slPriceA, uint256 slPriceB, uint256 latestPrice)
        internal
    {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        req.slPrice.priceA = slPriceA;
        req.slPrice.priceB = slPriceB;
        pythnode.setLatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, userKey);
    }

    function setTpSlPrices(
        uint256 priceA,
        uint256 priceB,
        uint256 tpPriceA,
        uint256 tpPriceB,
        uint256 slPriceA,
        uint256 slPriceB,
        uint256 latestPrice
    ) internal {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        req.tpPrice.priceA = tpPriceA;
        req.tpPrice.priceB = tpPriceB;
        req.slPrice.priceA = slPriceA;
        req.slPrice.priceB = slPriceB;
        pythnode.setLatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, userKey);
    }

    function placeOrder() internal {
        vm.prank(address(account));
        synthetixLimitOrders.placeOrder(req);
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Test - Initialize
    /// -----------------------------------------------------------------------

    function test_cannotInitializeTwice() external {
        vm.expectRevert();
        synthetixLimitOrders.initialize(owner, address(list), address(pythnode), address(perpMarket));
    }

    /// -----------------------------------------------------------------------
    /// Test - Place Order (onchain)
    /// -----------------------------------------------------------------------

    function test_placeOrder_withValidPrice() external {
        setPrices(1, 2, 0);
        vm.prank(address(account));
        synthetixLimitOrders.placeOrder(req);

        assertEq(synthetixLimitOrders.nextOrderId(), 2);
        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.SUBMITTED);
    }

    function test_placeOrder_withDifferentSCW() external {
        IAccount account2 = new MockIAccount();

        setPrices(1, 2, 0);
        vm.prank(address(account2));
        vm.expectRevert(
            abi.encodeWithSelector(SynthetixLimitOrdersV3.NotAuthorized.selector, address(account), address(account2))
        );
        synthetixLimitOrders.placeOrder(req);
    }

    function test_placeOrder_withInvalidPrice() external {
        uint256[3] memory priceAs = [uint256(0), 1, 2];
        uint256[3] memory priceBs = [uint256(1), 0, 1];

        for (uint8 index = 0; index < 3; index++) {
            setPrices(priceAs[index], priceBs[index], 0);
            vm.prank(address(account));
            synthetixLimitOrders.placeOrder(req);
            assertEq(synthetixLimitOrders.nextOrderId(), index + 2);
            assert(synthetixLimitOrders.status(index + 1) == SynthetixLimitOrdersV3.OrderStatus.EXECUTED);
        }
    }

    /// -----------------------------------------------------------------------
    /// Test - Cancel Order (offchain)
    /// -----------------------------------------------------------------------

    function test_cancelOrderOffChain_byNonAuthorized() external {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.NotAuthorized.selector, user, someone));
        synthetixLimitOrders.cancelOrder(req, sig);
    }

    function test_cancelOrderOffChain_successBySigner() external {
        vm.prank(user);
        synthetixLimitOrders.cancelOrder(req, sig);

        assertEq(synthetixLimitOrders.cancelledHashes(keccak256(sig)), true);
    }

    function test_cancelOrderOffChain_successByUser() external {
        vm.prank(address(account));
        synthetixLimitOrders.cancelOrder(req, sig);

        assertEq(synthetixLimitOrders.cancelledHashes(keccak256(sig)), true);
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute Order (offchain)
    /// -----------------------------------------------------------------------

    function test_executeOrderOffChain_withInvalidPrice() external {
        setPrices(0, 1, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);

        setPrices(1, 0, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);

        setPrices(2, 1, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withExpiredOrder() external {
        setPrices(10, 100, 50);

        vm.prank(someone);
        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExpired.selector, req.expiry, expiry + 1));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withZeroSize() external {
        req.size = 0;
        setPrices(10, 100, 50);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderSizeZero.selector));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withCancelledSig() external {
        setPrices(10, 100, 50);

        vm.prank(user);
        synthetixLimitOrders.cancelOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withSubmittedSig() external {
        setPrices(10, 100, 50);

        vm.prank(someone);
        synthetixLimitOrders.executeOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_withNotInRangeLatestPrice() external {
        setPrices(10, 100, 9);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 9
            )
        );
        synthetixLimitOrders.executeOrder(req, sig);

        setPrices(10, 100, 101);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 101
            )
        );
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrderOffChain_successWithoutTPorSL() external {
        setPrices(10, 100, 50);

        vm.prank(someone);
        synthetixLimitOrders.executeOrder(req, sig);

        assertEq(synthetixLimitOrders.nextOrderId(), 2);
        assertEq(synthetixLimitOrders.submittedHashes(keccak256(sig)), true);
        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeOrderOffChain_successWithTP() external {
        setTpPrices(10, 100, 10, 100, 50);

        vm.prank(someone);
        synthetixLimitOrders.executeOrder(req, sig);

        assertEq(synthetixLimitOrders.nextOrderId(), 2);
        assertEq(synthetixLimitOrders.submittedHashes(keccak256(sig)), true);
        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.EXECUTED);
    }

    function test_executeOrderOffChain_successWithSL() external {
        setSlPrices(10, 100, 10, 100, 50);

        vm.prank(someone);
        synthetixLimitOrders.executeOrder(req, sig);

        assertEq(synthetixLimitOrders.nextOrderId(), 2);
        assertEq(synthetixLimitOrders.submittedHashes(keccak256(sig)), true);
        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.EXECUTED);
    }

    function test_executeOrderOffChain_castValues() external {
        req.price.acceptablePrice = 3;
        setPrices(10, 100, 50);

        vm.prank(someone);
        synthetixLimitOrders.executeOrder(req, sig);

        assertEq(account.data(), getCommitTradeHash(accountId, marketId, size, 3));
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute TP Order (offchain)
    /// -----------------------------------------------------------------------

    function test_executeTpOrderOffChain_withInvalidTpPrice() external {
        setTpPrices(0, 0, 0, 1, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(req, sig);

        setTpPrices(0, 0, 1, 0, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(req, sig);

        setTpPrices(0, 0, 2, 1, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrderOffChain_withValidPrice() external {
        setTpPrices(1, 2, 1, 2, 0);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderNotExecuted.selector, 0));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrderOffChain_withZeroSize() external {
        req.size = 0;
        setTpPrices(0, 0, 10, 100, 50);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderSizeZero.selector));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrderOffChain_withExpiredOrder() external {
        setTpPrices(0, 0, 10, 100, 50);

        vm.prank(someone);
        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExpired.selector, req.expiry, expiry + 1));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrderOffChain_withCancelledSig() external {
        setTpPrices(0, 0, 10, 100, 50);

        vm.prank(user);
        synthetixLimitOrders.cancelOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrderOffChain_withSubmittedSig() external {
        setTpPrices(0, 0, 10, 100, 50);

        vm.prank(someone);
        synthetixLimitOrders.executeTpOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrderOffChain_withNotInRangeLatestPrice() external {
        setTpPrices(0, 0, 10, 100, 9);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.tpPrice.priceA, req.tpPrice.priceB, 9
            )
        );
        synthetixLimitOrders.executeTpOrder(req, sig);

        setTpPrices(0, 0, 10, 100, 101);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.tpPrice.priceA, req.tpPrice.priceB, 101
            )
        );
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrderOffChain_success() external {
        setTpPrices(0, 0, 10, 100, 50);

        vm.prank(someone);
        synthetixLimitOrders.executeTpOrder(req, sig);

        assertEq(synthetixLimitOrders.nextOrderId(), 2);
        assertEq(synthetixLimitOrders.submittedHashes(keccak256(sig)), true);
        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeTpOrderOffChain_incompatibleSizes() external {
        int128[4] memory reqSizes = [int128(1), -1, 1, -1];
        int128[4] memory positionSizes = [int128(0), 0, -1, 1];

        for (uint8 index = 0; index < 4; index++) {
            req.size = reqSizes[index];
            perpMarket.setOpenPosition(positionSizes[index]);
            setTpPrices(0, 0, 10, 100, 50);

            vm.prank(someone);
            vm.expectRevert(
                abi.encodeWithSelector(
                    SynthetixLimitOrdersV3.PositionChangedDirection.selector, reqSizes[index], positionSizes[index]
                )
            );
            synthetixLimitOrders.executeTpOrder(req, sig);
        }
    }

    function test_executeTpOrderOffChain_castValues() external {
        int128[4] memory reqSizes = [int128(100), 20, -100, -100];
        int128[4] memory positionSizes = [int128(20), 100, -20, -20];
        int128[4] memory sizeDeltas = [int128(-20), -20, 20, 20];

        for (uint8 index = 0; index < 4; index++) {
            req.tpPrice.acceptablePrice = 33;
            req.size = reqSizes[index];
            req.expiry = expiry + index;
            perpMarket.setOpenPosition(positionSizes[index]);
            setTpPrices(0, 0, 10, 100, 50);

            vm.prank(someone);
            synthetixLimitOrders.executeTpOrder(req, sig);

            bytes memory expectedHash = getCommitTradeHash(accountId, marketId, sizeDeltas[index], 33);
            assertEq(account.data(), expectedHash);
        }
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute SL Order (offchain)
    /// -----------------------------------------------------------------------

    function test_executeSlOrderOffChain_withInvalidSlPrice() external {
        setSlPrices(0, 0, 0, 1, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(req, sig);

        setSlPrices(0, 0, 1, 0, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(req, sig);

        setSlPrices(0, 0, 2, 1, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrderOffChain_withValidPrice() external {
        setSlPrices(1, 2, 1, 2, 0);
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderNotExecuted.selector, 0));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executedSlOrderOffChain_withZeroSize() external {
        req.size = 0;
        setSlPrices(0, 0, 10, 100, 50);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderSizeZero.selector));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executedSlOrderOffChain_withExpiredOrder() external {
        setSlPrices(0, 0, 10, 100, 50);

        vm.prank(someone);
        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExpired.selector, req.expiry, expiry + 1));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrderOffChain_withCancelledSig() external {
        setSlPrices(0, 0, 10, 100, 50);
        vm.prank(user);
        synthetixLimitOrders.cancelOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrderOffChain_withSubmittedSig() external {
        setSlPrices(0, 0, 10, 100, 50);
        vm.prank(someone);
        synthetixLimitOrders.executeSlOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrderOffChain_withNotInRangeLatestPrice() external {
        setSlPrices(0, 0, 10, 100, 9);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.slPrice.priceA, req.slPrice.priceB, 9
            )
        );
        synthetixLimitOrders.executeSlOrder(req, sig);

        setSlPrices(0, 0, 10, 100, 101);
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.slPrice.priceA, req.slPrice.priceB, 101
            )
        );
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrderOffChain_success() external {
        setSlPrices(0, 0, 10, 100, 50);
        vm.prank(someone);
        synthetixLimitOrders.executeSlOrder(req, sig);

        assertEq(synthetixLimitOrders.nextOrderId(), 2);
        assertEq(synthetixLimitOrders.submittedHashes(keccak256(sig)), true);
        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeSlOrderOffChain_incompatibleSizes() external {
        int128[4] memory reqSizes = [int128(1), -1, 1, -1];
        int128[4] memory positionSizes = [int128(0), 0, -1, 1];

        for (uint8 index = 0; index < 4; index++) {
            req.size = reqSizes[index];
            perpMarket.setOpenPosition(positionSizes[index]);
            setSlPrices(0, 0, 10, 100, 50);

            vm.prank(someone);
            vm.expectRevert(
                abi.encodeWithSelector(
                    SynthetixLimitOrdersV3.PositionChangedDirection.selector, reqSizes[index], positionSizes[index]
                )
            );
            synthetixLimitOrders.executeSlOrder(req, sig);
        }
    }

    function test_executeSlOrderOffChain_castValues() external {
        int128[4] memory reqSizes = [int128(100), 20, -100, -100];
        int128[4] memory positionSizes = [int128(20), 100, -20, -20];
        int128[4] memory sizeDeltas = [int128(-20), -20, 20, 20];

        for (uint8 index = 0; index < 4; index++) {
            req.slPrice.acceptablePrice = 33;
            req.size = reqSizes[index];
            req.expiry = expiry + index;
            perpMarket.setOpenPosition(positionSizes[index]);
            setSlPrices(0, 0, 10, 100, 50);

            vm.prank(someone);
            synthetixLimitOrders.executeSlOrder(req, sig);

            bytes memory expectedHash = getCommitTradeHash(accountId, marketId, sizeDeltas[index], 33);
            assertEq(account.data(), expectedHash);
        }
    }

    /// -----------------------------------------------------------------------
    /// Test - Cancel Order (onchain)
    /// -----------------------------------------------------------------------

    function test_cancelOrderOnChain_byNonUser() external {
        placeOrder();

        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(SynthetixLimitOrdersV3.NotAuthorized.selector, address(account), someone)
        );
        synthetixLimitOrders.cancelOrder(1);
    }

    function test_cancelOrderOnChain_success() external {
        placeOrder();

        vm.prank(address(account));
        synthetixLimitOrders.cancelOrder(1);

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.CANCELLED);
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute Order (onchain)
    /// -----------------------------------------------------------------------

    function test_executeOrderOnChain_withExpiredOrder() external {
        placeOrder();

        vm.prank(someone);
        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExpired.selector, req.expiry, expiry + 1));
        synthetixLimitOrders.executeOrder(1);
    }

    function test_executeOrderOnChain_withCancelledOrder() external {
        placeOrder();

        vm.prank(address(account));
        synthetixLimitOrders.cancelOrder(1);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCancelled.selector, 1));
        synthetixLimitOrders.executeOrder(1);
    }

    function test_executeOrderOnChain_withExecutedOrder() external {
        setTpPrices(10, 100, 10, 100, 50);
        placeOrder();
        vm.prank(someone);
        synthetixLimitOrders.executeOrder(1);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExecuted.selector, 1));
        synthetixLimitOrders.executeOrder(1);

        setTpPrices(0, 0, 10, 100, 50);
        placeOrder();

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExecuted.selector, 2));
        synthetixLimitOrders.executeOrder(2);
    }

    function test_executeOrderOnChain_withCompletedOrder() external {
        setPrices(10, 100, 50);
        placeOrder();
        vm.prank(someone);
        synthetixLimitOrders.executeOrder(1);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCompleted.selector, 1));
        synthetixLimitOrders.executeOrder(1);
    }

    function test_executeOrderOnChain_withZeroSize() external {
        req.size = 0;
        setPrices(10, 100, 50);
        placeOrder();

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderSizeZero.selector));
        synthetixLimitOrders.executeOrder(1);
    }

    function test_executeOrderOnChain_withNotInRangeLatestPrice() external {
        setPrices(10, 100, 9);
        placeOrder();
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 9
            )
        );
        synthetixLimitOrders.executeOrder(1);

        setPrices(10, 100, 101);
        placeOrder();
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 101
            )
        );
        synthetixLimitOrders.executeOrder(2);
    }

    function test_executeOrderOnChain_successWithoutTPorSL() external {
        setPrices(10, 100, 50);
        placeOrder();
        vm.prank(someone);
        synthetixLimitOrders.executeOrder(1);

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeOrderOnChain_successWithTP() external {
        setTpPrices(10, 100, 10, 100, 50);
        placeOrder();
        vm.prank(someone);
        synthetixLimitOrders.executeOrder(1);

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.EXECUTED);
    }

    function test_executeOrderOnChain_successWithSL() external {
        setSlPrices(10, 100, 10, 100, 50);
        placeOrder();
        vm.prank(someone);
        synthetixLimitOrders.executeOrder(1);

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.EXECUTED);
    }

    function test_executeOrderOnChain_castValues() external {
        req.price.acceptablePrice = 3;
        setPrices(10, 100, 50);
        placeOrder();

        vm.prank(someone);
        synthetixLimitOrders.executeOrder(1);

        assertEq(account.data(), getCommitTradeHash(accountId, marketId, size, 3));
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute TP Order (onchain)
    /// -----------------------------------------------------------------------

    function test_executeTpOrderOnChain_withExpiredOrder() external {
        placeOrder();

        vm.prank(someone);
        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExpired.selector, req.expiry, expiry + 1));
        synthetixLimitOrders.executeTpOrder(1);
    }

    function test_executeTpOrderOnChain_withCancelled() external {
        placeOrder();

        vm.prank(address(account));
        synthetixLimitOrders.cancelOrder(1);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCancelled.selector, 1));
        synthetixLimitOrders.executeTpOrder(1);
    }

    function test_executeTpOrderOnChain_withSubmitted() external {
        setTpPrices(10, 100, 10, 100, 50);
        placeOrder();

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderNotExecuted.selector, 1));
        synthetixLimitOrders.executeTpOrder(1);
    }

    function test_executeTpOrderOnChain_withCompleted() external {
        setTpSlPrices(0, 0, 10, 100, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeTpOrder(1);

        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCompleted.selector, 1));
        synthetixLimitOrders.executeTpOrder(1);
        vm.stopPrank();

        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeSlOrder(2);

        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCompleted.selector, 2));
        synthetixLimitOrders.executeTpOrder(2);
        vm.stopPrank();
    }

    function test_executeTpOrderOnChain_withInvalidTpPriceRange() external {
        setTpSlPrices(0, 0, 1, 0, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(1);
        vm.stopPrank();

        setTpSlPrices(0, 0, 0, 1, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(2);
        vm.stopPrank();

        setTpSlPrices(0, 0, 2, 1, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(3);
        vm.stopPrank();
    }

    function test_executeTpOrderOnChain_withNotInRangeLatestPrice() external {
        setTpPrices(0, 0, 10, 100, 9);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.tpPrice.priceA, req.tpPrice.priceB, 9
            )
        );
        synthetixLimitOrders.executeTpOrder(1);
        vm.stopPrank();

        setTpPrices(0, 0, 10, 100, 101);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.tpPrice.priceA, req.tpPrice.priceB, 101
            )
        );
        synthetixLimitOrders.executeTpOrder(2);
        vm.stopPrank();
    }

    function test_executeTpOrderOnChain_success() external {
        setTpPrices(0, 0, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeTpOrder(1);
        vm.stopPrank();

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeTpOrderOnChain_successWithOnChainOrder() external {
        setTpPrices(10, 100, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeOrder(1);
        synthetixLimitOrders.executeTpOrder(1);
        vm.stopPrank();

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeTpOrderOnChain_successWithOffChainOrder() external {
        setTpPrices(10, 100, 10, 100, 50);

        vm.startPrank(someone);
        synthetixLimitOrders.executeOrder(req, sig);
        synthetixLimitOrders.executeTpOrder(1);
        vm.stopPrank();

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeTpOrderOnChain_incompatibleSizes() external {
        int128[4] memory reqSizes = [int128(1), -1, 1, -1];
        int128[4] memory positionSizes = [int128(0), 0, -1, 1];

        for (uint8 index = 0; index < 4; index++) {
            req.size = reqSizes[index];
            perpMarket.setOpenPosition(positionSizes[index]);
            setTpPrices(0, 0, 10, 100, 50);

            placeOrder();

            vm.startPrank(someone);
            vm.expectRevert(
                abi.encodeWithSelector(
                    SynthetixLimitOrdersV3.PositionChangedDirection.selector, reqSizes[index], positionSizes[index]
                )
            );
            synthetixLimitOrders.executeTpOrder(index + 1);
            vm.stopPrank();
        }
    }

    function test_executeTpOrderOnChain_castValues() external {
        int128[4] memory reqSizes = [int128(100), 20, -100, -100];
        int128[4] memory positionSizes = [int128(20), 100, -20, -20];
        int128[4] memory sizeDeltas = [int128(-20), -20, 20, 20];

        for (uint8 index = 0; index < 4; index++) {
            req.tpPrice.acceptablePrice = 33;
            req.size = reqSizes[index];
            perpMarket.setOpenPosition(positionSizes[index]);
            setTpPrices(0, 0, 10, 100, 50);

            placeOrder();
            vm.startPrank(someone);
            synthetixLimitOrders.executeTpOrder(index + 1);
            vm.stopPrank();

            bytes memory expectedHash = getCommitTradeHash(accountId, marketId, sizeDeltas[index], 33);
            assertEq(account.data(), expectedHash);
        }
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute SL Order (onchain)
    /// -----------------------------------------------------------------------

    function test_executeSlOrderOnChain_withExpiredOrder() external {
        placeOrder();

        vm.prank(someone);
        vm.warp(expiry + 1);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderExpired.selector, req.expiry, expiry + 1));
        synthetixLimitOrders.executeSlOrder(1);
    }

    function test_executeSlOrderOnChain_withCancelled() external {
        placeOrder();

        vm.prank(address(account));
        synthetixLimitOrders.cancelOrder(1);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCancelled.selector, 1));
        synthetixLimitOrders.executeSlOrder(1);
    }

    function test_executeSlOrderOnChain_withSubmitted() external {
        setSlPrices(10, 100, 10, 100, 50);
        placeOrder();

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderNotExecuted.selector, 1));
        synthetixLimitOrders.executeSlOrder(1);
    }

    function test_executeSlOrderOnChain_withCompleted() external {
        setTpSlPrices(0, 0, 10, 100, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeTpOrder(1);

        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCompleted.selector, 1));
        synthetixLimitOrders.executeSlOrder(1);
        vm.stopPrank();

        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeSlOrder(2);

        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderCompleted.selector, 2));
        synthetixLimitOrders.executeSlOrder(2);
        vm.stopPrank();
    }

    function test_executeSlOrderOnChain_withInvalidSlPriceRange() external {
        setTpSlPrices(0, 0, 10, 100, 1, 0, 50);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(1);
        vm.stopPrank();

        setTpSlPrices(0, 0, 10, 100, 0, 1, 50);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(2);
        vm.stopPrank();

        setTpSlPrices(0, 0, 10, 100, 2, 1, 50);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(3);
        vm.stopPrank();
    }

    function test_executeSlOrderOnChain_withNotInRangeLatestPrice() external {
        setSlPrices(0, 0, 10, 100, 9);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.slPrice.priceA, req.slPrice.priceB, 9
            )
        );
        synthetixLimitOrders.executeSlOrder(1);
        vm.stopPrank();

        setSlPrices(0, 0, 10, 100, 101);
        placeOrder();

        vm.startPrank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.slPrice.priceA, req.slPrice.priceB, 101
            )
        );
        synthetixLimitOrders.executeSlOrder(2);
        vm.stopPrank();
    }

    function test_executeSlOrderOnChain_success() external {
        setSlPrices(0, 0, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeSlOrder(1);
        vm.stopPrank();

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeSlOrderOnChain_successWithOnChainOrder() external {
        setSlPrices(10, 100, 10, 100, 50);
        placeOrder();

        vm.startPrank(someone);
        synthetixLimitOrders.executeOrder(1);
        synthetixLimitOrders.executeSlOrder(1);
        vm.stopPrank();

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeSlOrderOnChain_successWithOffChainOrder() external {
        setSlPrices(10, 100, 10, 100, 50);

        vm.startPrank(someone);
        synthetixLimitOrders.executeOrder(req, sig);
        synthetixLimitOrders.executeSlOrder(1);
        vm.stopPrank();

        assert(synthetixLimitOrders.status(1) == SynthetixLimitOrdersV3.OrderStatus.COMPLETED);
    }

    function test_executeSlOrderOnChain_incompatibleSizes() external {
        int128[4] memory reqSizes = [int128(1), -1, 1, -1];
        int128[4] memory positionSizes = [int128(0), 0, -1, 1];

        for (uint8 index = 0; index < 4; index++) {
            req.size = reqSizes[index];
            perpMarket.setOpenPosition(positionSizes[index]);
            setSlPrices(0, 0, 10, 100, 50);

            placeOrder();

            vm.startPrank(someone);
            vm.expectRevert(
                abi.encodeWithSelector(
                    SynthetixLimitOrdersV3.PositionChangedDirection.selector, reqSizes[index], positionSizes[index]
                )
            );
            synthetixLimitOrders.executeSlOrder(index + 1);
            vm.stopPrank();
        }
    }

    function test_executeSlOrderOnChain_castValues() external {
        int128[4] memory reqSizes = [int128(100), 20, -100, -100];
        int128[4] memory positionSizes = [int128(20), 100, -20, -20];
        int128[4] memory sizeDeltas = [int128(-20), -20, 20, 20];

        for (uint8 index = 0; index < 4; index++) {
            req.slPrice.acceptablePrice = 33;
            req.size = reqSizes[index];
            perpMarket.setOpenPosition(positionSizes[index]);
            setSlPrices(0, 0, 10, 100, 50);

            placeOrder();
            vm.startPrank(someone);
            synthetixLimitOrders.executeSlOrder(index + 1);
            vm.stopPrank();

            bytes memory expectedHash = getCommitTradeHash(accountId, marketId, sizeDeltas[index], 33);
            assertEq(account.data(), expectedHash);
        }
    }
}
