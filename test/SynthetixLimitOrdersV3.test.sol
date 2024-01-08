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
} from "../src/automations/SynthetixLimitOrdersV3.sol";
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
    address scw;
    address user;
    uint256 userKey;
    address someone;

    IList list;
    MockIPythNode pythnode;
    IPyth pyth;
    IPerpMarket perpMarket;
    IAccount account;
    SynthetixLimitOrdersV3.OrderRequest req;
    bytes sig;

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
        scw = makeAddr("SmartContractWallet");
        (user, userKey) = makeAddrAndKey("User");
        someone = makeAddr("Someone");

        // mocks

        list = new MockIList();
        pyth = new MockIPyth();
        pythnode = new MockIPythNode(pyth);
        perpMarket = new MockIPerpMarket();
        account = new MockIAccount();

        // setups

        SynthetixLimitOrdersV3.PriceRange memory range = SynthetixLimitOrdersV3.PriceRange(10, 100, 50);
        pythnode.setLatestPrice(50);
        req = SynthetixLimitOrdersV3.OrderRequest(address(account), range, range, range, 1, 1, 1, 1);
        sig = computeOrderRequestSign(req, userKey);

        synthetixLimitOrders.initialize(user, address(list), address(pythnode), address(perpMarket));
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

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier mockedValues(uint256 priceA, uint256 priceB, uint256 latestPrice) {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        pythnode.setLatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, userKey);
        _;
    }

    modifier mockedTpValues(uint256 priceA, uint256 priceB, uint256 tpPriceA, uint256 tpPriceB, uint256 latestPrice) {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        req.tpPrice.priceA = tpPriceA;
        req.tpPrice.priceB = tpPriceB;
        pythnode.setLatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, userKey);
        _;
    }

    modifier mockedSlValues(uint256 priceA, uint256 priceB, uint256 slPriceA, uint256 slPriceB, uint256 latestPrice) {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        req.slPrice.priceA = slPriceA;
        req.slPrice.priceB = slPriceB;
        pythnode.setLatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, userKey);
        _;
    }

    /// -----------------------------------------------------------------------
    /// Test - Initialize
    /// -----------------------------------------------------------------------

    function test_cannotInitializeTwice() external {
        vm.expectRevert();
        synthetixLimitOrders.initialize(owner, address(list), address(pythnode), address(perpMarket));
    }

    /// -----------------------------------------------------------------------
    /// Test - Cancel Order (offchain)
    /// -----------------------------------------------------------------------

    function test_cancelOrder_byNonSigner() external {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.NotAuthorized.selector, user, someone));
        synthetixLimitOrders.cancelOrder(req, sig);
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute Order (offchain)
    /// -----------------------------------------------------------------------

    function test_executeOrder_withPriceAZeros() external mockedValues(0, 1, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withPriceBZeros() external mockedValues(1, 0, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withInvertedPriceRange() external mockedValues(2, 1, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withCancelledSig() external {
        vm.prank(user);
        synthetixLimitOrders.cancelOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withSubmittedSig() external {
        vm.prank(someone);
        synthetixLimitOrders.executeOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withlowerLatestPrice() external mockedValues(10, 100, 9) {
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 9
            )
        );
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withHigherLatestPrice() external mockedValues(10, 100, 101) {
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 101
            )
        );
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_success() external {
        vm.prank(someone);
        synthetixLimitOrders.executeOrder(req, sig);
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute TP Order (offchain)
    /// -----------------------------------------------------------------------

    function test_executeTpOrder_withTpPriceAZeros() external mockedTpValues(0, 0, 0, 1, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_withTpPriceBZeros() external mockedTpValues(0, 0, 1, 0, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_withInvertedTpPriceRange() external mockedTpValues(0, 0, 2, 1, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.tpPrice));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_withValidPrice() external mockedTpValues(1, 2, 1, 2, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderNotExecuted.selector, 0));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_withCancelledSig() external mockedValues(0, 0, 0) {
        vm.prank(user);
        synthetixLimitOrders.cancelOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_withSubmittedSig() external mockedTpValues(0, 0, 10, 100, 50) {
        vm.prank(someone);
        synthetixLimitOrders.executeTpOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_withlowerLatestPrice() external mockedTpValues(0, 0, 10, 100, 9) {
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.tpPrice.priceA, req.tpPrice.priceB, 9
            )
        );
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_withHigherLatestPrice() external mockedTpValues(0, 0, 10, 100, 101) {
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.tpPrice.priceA, req.tpPrice.priceB, 101
            )
        );
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    function test_executeTpOrder_success() external mockedTpValues(0, 0, 10, 100, 50) {
        vm.prank(someone);
        synthetixLimitOrders.executeTpOrder(req, sig);
    }

    /// -----------------------------------------------------------------------
    /// Test - Execute SL Order (offchain)
    /// -----------------------------------------------------------------------

    function test_executeSlOrder_withSlPriceAZeros() external mockedSlValues(0, 0, 0, 1, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_withSlPriceBZeros() external mockedSlValues(0, 0, 1, 0, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_withInvertedSlPriceRange() external mockedSlValues(0, 0, 2, 1, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.slPrice));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_withValidPrice() external mockedSlValues(1, 2, 1, 2, 0) {
        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.OrderNotExecuted.selector, 0));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_withCancelledSig() external mockedValues(0, 0, 0) {
        vm.prank(user);
        synthetixLimitOrders.cancelOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_withSubmittedSig() external mockedSlValues(0, 0, 10, 100, 50) {
        vm.prank(someone);
        synthetixLimitOrders.executeSlOrder(req, sig);

        vm.prank(someone);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_withlowerLatestPrice() external mockedSlValues(0, 0, 10, 100, 9) {
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.slPrice.priceA, req.slPrice.priceB, 9
            )
        );
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_withHigherLatestPrice() external mockedSlValues(0, 0, 10, 100, 101) {
        vm.prank(someone);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.slPrice.priceA, req.slPrice.priceB, 101
            )
        );
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    function test_executeSlOrder_success() external mockedSlValues(0, 0, 10, 100, 50) {
        vm.prank(someone);
        synthetixLimitOrders.executeSlOrder(req, sig);
    }

    // TODO(Push): tp/sl can only be executed once the initial limit order is executed (if any)
    // TODO(Push): only one of tp or sl can be executed
    // TODO(Push): check both cases where tp/sl is submitted via offchain sig directly (without initial limit order) and on-chain order id
    // TODO(Push): add a check, if the block timestamp is after expiry don't execute
    // TODO(Push): check available price usage in _cast spells
}
