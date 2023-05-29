// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AccountResolver} from "../src/resolvers/Accounts.sol";

contract DeployResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new AccountResolver(0xC7a069dD24178DF00914d49Bf674A40A1420CF01);
        vm.stopBroadcast();
    }
}
