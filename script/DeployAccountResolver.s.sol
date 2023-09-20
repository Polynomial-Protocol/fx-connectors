// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AccountResolver} from "../src/resolvers/Accounts.sol";

contract DeployResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);
        new AccountResolver(0xe7FcA4a9cCC5DE4917C98277e7BeE81782a5Cd01);
        vm.stopBroadcast();
    }
}
