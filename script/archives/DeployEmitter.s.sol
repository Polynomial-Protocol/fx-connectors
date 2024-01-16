// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PolyEmitter} from "../../src/common/utils/Emitter.sol";
import {TransparentUpgradeableProxy} from "../../src/common/proxy/TransparentUpgradeProxy.sol";

contract DeployEmitter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = 0x657167F589aA788A52979d4F40f74B6d82aAA6c5;
        // bytes memory data = abi.encodeWithSelector(PolyEmitter.initialize.selector);

        PolyEmitter emitter = new PolyEmitter();

        // TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        //     address(emitter),
        //     admin,
        //     ""
        // );

        vm.stopBroadcast();
    }
}
