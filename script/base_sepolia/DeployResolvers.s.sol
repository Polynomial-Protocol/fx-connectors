// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AccountResolver} from "../../src/common/resolvers/Accounts.sol";
import {SynthetixPerpAccountsResolver} from "../../src/common/resolvers/SynthetixPerpAccounts.sol";

contract DeployResolvers is Script {
    address constant indexAddr = 0xF18C8a7C78b60D4b7EE00cBc1D5B62B643d03404;
    // get from synthetix
    address constant snxPerpAccountAddr = 0x0000000000000000000000000000000000000000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        new AccountResolver(indexAddr);
        new SynthetixPerpAccountsResolver(snxPerpAccountAddr);
        vm.stopBroadcast();
    }
}
