// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AccountResolver} from "../src/resolvers/Accounts.sol";

contract DeployStorage is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new AccountResolver(0x2A053Fe415f10C1D9A16920eeB5b5d3D05Ff792F);
        vm.stopBroadcast();
    }
}
