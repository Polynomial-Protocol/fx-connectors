// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {PowerPerpConnector} from "../src/connectors/PowerPerp.sol";
import {console2} from "forge-std/console2.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {TradeParams} from "../src/connectors/PowerPerp.sol";

interface ILiquidityPool {
    function orderFee(int256 sizeDelta) external view returns (uint256);

    function queueDeposit(uint256 amount, address user) external;
    function queueWithdraw(uint256 amount, address user) external;
    function deposit(uint256 amount, address user) external;
    function withdraw(uint256 tokens, address user) external;
    function processDeposits(uint256) external;
}

interface IExchange {
    function getMarkPrice() external view returns (uint256 markPrice, bool isInvalid);

    function openTrade(TradeParams memory tradeParams) external returns (uint256 positionId, uint256 totalCost);

    function closeTrade(TradeParams memory tradeParams) external returns (uint256 totalCost);
}

contract PowerPerpTest is Script, Test {
    using FixedPointMathLib for uint256;

    address addr = 0x1A540dBb56dA7BDF0AEAC4d36ea759C86a5E9E63;
    ERC20 liquidityToken = ERC20(0x71055Ad10c8B0D5C8d30295CfcE32bE7aA1f1133);
    ILiquidityPool pool = ILiquidityPool(0xFEe7e4015e12C6450BEb04784fEf916a31CD79CF);
    IExchange exchange = IExchange(0xbd087DfDcf7739B6A6dd8167239273fB3cDcBf92);
    ERC20 powerPerp = ERC20(0xF80EeBec5A7BeaBE094fd043d55B28D908c12375);

    function test() public {
        PowerPerpConnector connector = new PowerPerpConnector(
            0x71055Ad10c8B0D5C8d30295CfcE32bE7aA1f1133,
            0xF80EeBec5A7BeaBE094fd043d55B28D908c12375,
            0x7B15b1EbE6D51e241375FF287476D4379889DDb6,
            0xFEe7e4015e12C6450BEb04784fEf916a31CD79CF,
            0xbd087DfDcf7739B6A6dd8167239273fB3cDcBf92
        );
        ERC20 susd = ERC20(0xeBaEAAD9236615542844adC5c149F86C36aD1136);
        vm.prank(addr);
        susd.transfer(address(connector), 2e20);

        connector.initiateDeposit(1e20, 0, 0);
        vm.warp(block.timestamp + 60);
        pool.processDeposits(1);

        uint256 ammt = 1e18;
        (uint256 markPrice,) = exchange.getMarkPrice();
        uint256 tokens = ammt.divWadUp(markPrice);
        console2.log("tokens: %d", tokens);
        TradeParams memory tradeParams = TradeParams({
            isLong: true,
            collateral: address(susd),
            positionId: 0,
            amount: tokens,
            collateralAmount: 0,
            minCost: 0,
            maxCost: 1e36,
            referralCode: bytes32(0)
        });
        connector.openTrade(tradeParams, 0, 0);

        console2.log("balance: %d", powerPerp.balanceOf(address(connector)));
    }
}
