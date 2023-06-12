// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BellPepper} from "../src/resolvers/BellPepper.sol";

contract DeployBellPepper is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);
        new BellPepper(0xedf10514EF611e3808622f24e236b83cB9E51dCe);
        vm.stopBroadcast();
    }
}
