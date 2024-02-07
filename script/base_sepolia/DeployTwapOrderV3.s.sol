// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixTwapOrdersV3} from "../../src/common/automations/SynthetixTwapOrdersV3.sol";
import {TransparentUpgradeableProxy} from "../../src/common/proxy/TransparentUpgradeProxy.sol";

contract DeployTwapOrder is Script {
    address constant ADMIN = 0x2b02AAd6f1694E7D9c934B7b3Ec444541286cF0f;
    address constant OWNER = 0xe5C3A8a8d696B0F9569EF48F944d4cc8d7979316;
    address constant POLYLIST = 0x89cd791Bf712673119cdA9ceCf7eAE1cc0C12d0c;
    address constant PYTHNODE = 0xBf01fE835b3315968bbc094f50AE3164e6d3D969;
    address constant PERP_MARKET = 0xE6C5f05C415126E6b81FCc3619f65Db2fCAd58D0;

    uint128[] MARKET_IDS = [
        100, // eth
        200 // btc
    ];

    bytes32[] PRICE_IDS = [
        bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace), // eth
        bytes32(0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43) // btc
    ];

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        SynthetixTwapOrdersV3 synthetixTwapOrders = new SynthetixTwapOrdersV3();

        bytes memory data =
            abi.encodeWithSelector(SynthetixTwapOrdersV3.initialize.selector, OWNER, POLYLIST, PYTHNODE, PERP_MARKET);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(synthetixTwapOrders), ADMIN, data);

        SynthetixTwapOrdersV3 target = SynthetixTwapOrdersV3(payable(address(proxy)));

        target.updatePriceIds(MARKET_IDS, PRICE_IDS);

        vm.stopBroadcast();
    }
}
