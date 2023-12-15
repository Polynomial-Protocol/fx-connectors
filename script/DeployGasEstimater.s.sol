// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {GasEstimater} from "../src/utils/GasEstimater.sol";
import {TransparentUpgradeableProxy} from "../src/proxy/TransparentUpgradeProxy.sol";

contract DeployGasEstimater is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = 0x59672D112d680CE34C20fF1507197993CC0bA430;
        bytes memory data = abi.encodeWithSelector(
            GasEstimater.initialize.selector, 0x9f76043B23125024Ce5f0Fb4AE707482107dd2a8, 1e18, 10e18, 50000, 1800000
        );

        GasEstimater estimater = new GasEstimater();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(estimater), admin, data);

        vm.stopBroadcast();
    }
}
