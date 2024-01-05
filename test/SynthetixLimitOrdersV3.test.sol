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

        synthetixLimitOrders = new SynthetixLimitOrdersV3();
        owner = makeAddr("Owner");
        scw = makeAddr("SmartContractWallet");

        assertEq(block.chainid, 31337);

        list = new MockIList();
        pyth = new MockIPyth();
        pythnode = new MockIPythNode(pyth);
        perpMarket = new MockIPerpMarket();
        account = new MockIAccount();

        SynthetixLimitOrdersV3.PriceRange memory range = SynthetixLimitOrdersV3.PriceRange(1, 1 ether, 0.5 ether);
        req = SynthetixLimitOrdersV3.OrderRequest(address(account), range, range, range, 1, 1, 1, 1);

        synthetixLimitOrders.initialize(owner, address(list), address(pythnode), address(perpMarket));
    }

    /// -----------------------------------------------------------------------
    /// helpers
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

    modifier mockeValues(uint256 priceA, uint256 priceB, uint256 latestPrice) {
        req.price.priceA = priceA;
        req.price.priceB = priceB;
        pythnode.setatestPrice(int256(latestPrice));

        sig = computeOrderRequestSign(req, uint256(1));
        _;
    }

    /// -----------------------------------------------------------------------
    /// Test
    /// -----------------------------------------------------------------------

    function test_cannotInitializeTwice() external {
        vm.expectRevert();
        synthetixLimitOrders.initialize(owner, address(list), address(pythnode), address(perpMarket));
    }

    function test_placeOrder_success() external {
        assertEq(synthetixLimitOrders.nextOrderId(), 1);

        vm.prank(scw);
        synthetixLimitOrders.placeOrder(req);

        assertEq(synthetixLimitOrders.nextOrderId(), 2);
    }

    function test_executeOrder_withPriceAZeros() external mockeValues(0, 1, 0) {
        vm.prank(scw);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withPriceBZeros() external mockeValues(1, 0, 0) {
        vm.prank(scw);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withInvertedPriceRange() external mockeValues(2, 1, 0) {
        vm.prank(scw);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.InvalidPriceRange.selector, req.price));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withCancelledSig() external {
        sig = "abc";
        synthetixLimitOrders.cancelOrder(sig);

        vm.prank(scw);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureCancelled.selector, keccak256(sig)));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withSubmittedSig() external mockeValues(10, 100, 50) {
        vm.prank(scw);
        synthetixLimitOrders.executeOrder(req, sig);

        vm.prank(scw);
        vm.expectRevert(abi.encodeWithSelector(SynthetixLimitOrdersV3.SignatureSubmitted.selector, keccak256(sig)));
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withlowerLatestPrice() external mockeValues(10, 100, 9) {
        vm.prank(scw);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 9
            )
        );
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_withHigherLatestPrice() external mockeValues(10, 100, 101) {
        vm.prank(scw);
        vm.expectRevert(
            abi.encodeWithSelector(
                SynthetixLimitOrdersV3.PriceNotInRange.selector, req.price.priceA, req.price.priceB, 101
            )
        );
        synthetixLimitOrders.executeOrder(req, sig);
    }

    function test_executeOrder_success() external mockeValues(10, 100, 50) {
        vm.prank(scw);
        synthetixLimitOrders.executeOrder(req, sig);
    }
}
