// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixAdvancedOrdersConnector} from "../src/connectors/SynthetixAdvancedOrders.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

        SynthetixAdvancedOrdersConnector advanced = new SynthetixAdvancedOrdersConnector();

        string[] memory names = new string[](1);
        names[0] = advanced.name();

        address[] memory addrs = new address[](1);
        addrs[0] = address(advanced);

        connectors.addConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
