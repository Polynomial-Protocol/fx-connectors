// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PowerPerpResolver} from "../../src/resolvers/PowerPerp.sol";

contract DeployPowerPerpResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new PowerPerpResolver(0x5313f042D3cB1C6428bD4Ab987d63502e70A314f);
        vm.stopBroadcast();
    }
}
