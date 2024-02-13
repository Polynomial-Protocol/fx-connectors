// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixLimitOrdersV3} from "../../src/common/automations/SynthetixLimitOrdersV3.sol";
import {TransparentUpgradeableProxy} from "../../src/common/proxy/TransparentUpgradeProxy.sol";

contract DeployLimitOrder is Script {
    address payable constant LIMIT_ORDER_PROXY = payable(0xf20E2ed5cf876C8E25996D2dAB9DDe51D682DfE6);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        SynthetixLimitOrdersV3 synthetixLimitOrders = new SynthetixLimitOrdersV3();

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(LIMIT_ORDER_PROXY);
        proxy.upgradeTo(address(synthetixLimitOrders));
        vm.stopBroadcast();
    }
}
