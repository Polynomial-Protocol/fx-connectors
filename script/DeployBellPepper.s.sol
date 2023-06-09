// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BellPepper} from "../src/resolvers/BellPepper.sol";

contract DeployBellPepper is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new BellPepper(0x649F44CAC3276557D03223Dbf6395Af65b11c11c);
        vm.stopBroadcast();
    }
}
