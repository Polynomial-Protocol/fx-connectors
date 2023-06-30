// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PowerPerpResolver} from "../../src/resolvers/PowerPerp.sol";

contract DeployPowerPerpResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new PowerPerpResolver(0x84b5245ba6Dc0Aea32209fb6C96ca090F8d7bbbc);
        vm.stopBroadcast();
    }
}
