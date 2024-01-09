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
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(0x90c5D64a67425d03774439d8d37194B29C2070FA);

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        SynthetixSpotV3Connector snxV3 = new SynthetixSpotV3Connector(
            0x18141523403e2595D31b22604AcB8Fc06a4CaA61,
            0x09d51516F38980035153a554c26Df3C6f51a23C3,
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        );

        names[0] = snxV3.name();

        addrs[0] = address(snxV3);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
