// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BasicConnector} from "../src/connectors/Basic.sol";
import {SynthetixSpotConnector} from "../src/connectors/SynthetixSpot.sol";
import {OneInchConnector} from "../src/connectors/OneInch.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

        SynthetixSpotConnector synthetixSpot = new SynthetixSpotConnector();
        OneInchConnector oneInch = new OneInchConnector();

        string[] memory names = new string[](2);
        names[0] = synthetixSpot.name();
        names[1] = oneInch.name();

        address[] memory addrs = new address[](2);
        addrs[0] = address(synthetixSpot);
        addrs[1] = address(oneInch);

        connectors.addConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
