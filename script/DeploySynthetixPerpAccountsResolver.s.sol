// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpAccountsResolver} from "../src/resolvers/SynthetixPerpAccounts.sol";

contract DeployResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);
        new SynthetixPerpAccountsResolver(0x518F2905b24AE298Ca06C1137b806DD5ACD493b6);
        vm.stopBroadcast();
    }
}
