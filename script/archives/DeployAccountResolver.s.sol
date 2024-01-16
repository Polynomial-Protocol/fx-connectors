// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AccountResolver} from "../../src/common/resolvers/Accounts.sol";

contract DeployResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new AccountResolver(0x2d4937ED79D434290c4baeA6d390b78c0bf907d8);
        vm.stopBroadcast();
    }
}
