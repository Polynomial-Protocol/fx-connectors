// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixLimitOrders} from "../../src/common/automations/SynthetixLimitOrders.sol";

contract DeployAutomation is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new SynthetixLimitOrders();

        vm.stopBroadcast();
    }
}
