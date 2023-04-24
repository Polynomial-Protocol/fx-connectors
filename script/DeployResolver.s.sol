// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpResolver} from "../src/resolvers/SynthetixPerp.sol";
import {PowerPerpResolver} from "../src/resolvers/PowerPerp.sol";

contract DeployResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new PowerPerpResolver(0xe61063AA819cF23855Ea5DE3904900c42A5d05FA);
        vm.stopBroadcast();
    }
}
