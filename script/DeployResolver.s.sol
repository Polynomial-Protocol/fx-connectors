// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AccountResolver} from "../src/resolvers/Accounts.sol";

contract DeployStorage is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new AccountResolver(0xb43c0899ECCf98BC7A0f3e2c2A211d6fc4f9b3fE);
        vm.stopBroadcast();
    }
}
