// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpResolver} from "../../src/common/resolvers/SynthetixPerp.sol";
import {TransparentUpgradeableProxy} from "../../src/common/proxy/TransparentUpgradeProxy.sol";

contract DeployProxyResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SynthetixPerpResolver resolver = new SynthetixPerpResolver();

        TransparentUpgradeableProxy proxy =
            TransparentUpgradeableProxy(payable(0x50fF859DE6bc8E71aCc1Dd73E5C4d15B46d04E63));
        proxy.upgradeTo(address(resolver));

        vm.stopBroadcast();
    }
}
