// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixLimitOrders} from "../../src/mainnet/optimism/automations/SynthetixLimitOrders.sol";
import {TransparentUpgradeableProxy} from "../../src/mainnet/optimism/common/proxy/TransparentUpgradeProxy.sol";

contract DeployLimitOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = vm.addr(deployerPrivateKey);

        SynthetixLimitOrders limitOrder = new SynthetixLimitOrders();
        bytes memory data = abi.encodeWithSelector(
            SynthetixLimitOrders.initialize.selector,
            0x59672D112d680CE34C20fF1507197993CC0bA430,
            2000000000000000000,
            300000000000000
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(limitOrder), admin, data);

        console2.log(address(limitOrder));
        console2.logBytes(data);

        vm.stopBroadcast();
    }
}
