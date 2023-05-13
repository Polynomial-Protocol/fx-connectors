// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpResolver} from "../src/resolvers/SynthetixPerp.sol";
import {TransparentUpgradeableProxy} from "../src/proxy/TransparentUpgradeProxy.sol";

contract DeployProxyResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // address admin = vm.addr(deployerPrivateKey);

        SynthetixPerpResolver resolver = new SynthetixPerpResolver();
        // new TransparentUpgradeableProxy(address(resolver), admin, "");

        vm.stopBroadcast();
    }
}
