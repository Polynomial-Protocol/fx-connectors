// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixSpotV3Connector} from "../src/connectors/SynthetixSpotV3.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(0x95325058C51Acc796E35F3D0309Ff098c4f818F1);

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        SynthetixSpotV3Connector snxV3 =
        new SynthetixSpotV3Connector(0x41A883a85b1AdE59F41d459Fa550b40fa56429DB, 0xC9ee9628f23b14483EA413C28712690E8D2dC6a3, 0x7056F16f58638253B8A1E5023d67a8CF98000681);

        names[0] = snxV3.name();

        addrs[0] = address(snxV3);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
