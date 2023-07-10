// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PowerPerpResolver} from "../../src/resolvers/PowerPerp.sol";

contract DeployPowerPerpResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address systemManager = 0x950829337ff723A5d75cC677121C6b08cbb63132;
        new PowerPerpResolver(systemManager);
        vm.stopBroadcast();
    }
}
