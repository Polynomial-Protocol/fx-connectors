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

interface MainImplementation {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin)
        external
        payable
        returns (bytes32);
}

interface PolyConnectorsInterface {
    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract PowerPerpTest is Script, Test {
    using FixedPointMathLib for uint256;

    address addr = 0x1A540dBb56dA7BDF0AEAC4d36ea759C86a5E9E63;
    address addr2 = 0xC17412b6131A01E128227fE2b2A2220e18338f78;
    ERC20 liquidityToken = ERC20(0x71055Ad10c8B0D5C8d30295CfcE32bE7aA1f1133);
    ILiquidityPool pool = ILiquidityPool(0xe61063AA819cF23855Ea5DE3904900c42A5d05FA);
    IExchange exchange = IExchange(0x1b110A6f51aC11AEf15a0bDF7C5AeBD7459CfB58);
    ERC20 powerPerp = ERC20(0x346b9325B26A5aAa133Bf70F71A6b5B60C52f8e3);
    address controller = 0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2;
    address index = 0xC7a069dD24178DF00914d49Bf674A40A1420CF01;
    ERC20 susd = ERC20(0xeBaEAAD9236615542844adC5c149F86C36aD1136);
    address scWallet = 0x5FB645484dBfBf75d1d3BeE17aD7CeF0E497d788;
    address scWallet2 = 0x73090A14ccC9902803526F235faD667821B3687F;
    address ZERO = 0x0000000000000000000000000000000000000000;

    function getConnector() public returns (PowerPerpConnector) {
        PowerPerpConnector connector = new PowerPerpConnector(
            0xff1d6e32cbe6d15c469728cE19F34Ae23F6B3177,
            0x346b9325B26A5aAa133Bf70F71A6b5B60C52f8e3,
            0x480b8fa01BC751C9583c23FAfDC8F5ea7ACA2D0e,
            0xe61063AA819cF23855Ea5DE3904900c42A5d05FA,
            0x1b110A6f51aC11AEf15a0bDF7C5AeBD7459CfB58
        );
        return connector;
    }

    function updateConnector(PowerPerpConnector connector) public {
        PolyConnectorsInterface polyConnectors = PolyConnectorsInterface(controller);
        address[] memory t = new address[](1);
        t[0] = address(connector);
        string[] memory names = new string[](1);
        names[0] = "Power-Perp-v1";
        vm.prank(addr);
        polyConnectors.updateConnectors(names, t);
    }

    function testLong() public {
        PowerPerpConnector connector = getConnector();
        updateConnector(connector);
        MainImplementation main = MainImplementation(scWallet);

        uint256 ammt = 1e18;
        (uint256 markPrice,) = exchange.getMarkPrice();
        uint256 tokens = ammt.divWadUp(markPrice);
        console2.log("tokens: %d", tokens);
        TradeParams memory tradeParams = TradeParams({
            isLong: true,
            collateral: ZERO,
            positionId: 0,
            amount: tokens,
            collateralAmount: 0,
            minCost: 0,
            maxCost: 1e36,
            referralCode: bytes32(0)
        });
        string[] memory targets = new string[](1);
        targets[0] = "Power-Perp-v1";
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeWithSelector(PowerPerpConnector.openTrade.selector, tradeParams, 0, 0);
        vm.prank(addr);
        main.cast(targets, datas, ZERO);
        console2.log("balance: %d", powerPerp.balanceOf(scWallet));
    }

    function testShort() public {
        PowerPerpConnector connector = getConnector();
        updateConnector(connector);
        console2.log("balance: %d", susd.balanceOf(scWallet2));
        MainImplementation main = MainImplementation(scWallet2);
        uint256 ammt = 1e18;
        (uint256 markPrice,) = exchange.getMarkPrice();
        uint256 tokens = ammt.divWadUp(markPrice);
        console2.log("tokens: %d", tokens);
        TradeParams memory tradeParams = TradeParams({
            isLong: false,
            collateral: address(susd),
            positionId: 0,
            amount: tokens,
            collateralAmount: 2 * ammt,
            minCost: 0,
            maxCost: 1e36,
            referralCode: bytes32(0)
        });
        string[] memory targets = new string[](1);
        targets[0] = "Power-Perp-v1";
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encodeWithSelector(PowerPerpConnector.openTrade.selector, tradeParams, 0, 0);
        vm.prank(addr2);
        main.cast(targets, datas, ZERO);
    }
}
