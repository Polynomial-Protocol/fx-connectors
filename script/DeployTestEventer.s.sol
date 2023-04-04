// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {TestEventer} from "../src/utils/TestContract.sol";
import {TransparentUpgradeableProxy} from "../src/proxy/TransparentUpgradeProxy.sol";

contract DeployTestEventer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = vm.addr(deployerPrivateKey);

        TestEventer eventer = new TestEventer();
        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(0xE6C7a70b43cdc28C45705FAdd3F79Bdb2D1bc702));

        proxy.upgradeTo(address(eventer));

        vm.stopBroadcast();
    }
}
