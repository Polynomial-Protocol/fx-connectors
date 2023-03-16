// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpLimitOrderConnector, ILimitOrder} from "../src/connectors/SynthetixPerpLimitOrder.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

        SynthetixPerpLimitOrderConnector limitOrder =
            new SynthetixPerpLimitOrderConnector(ILimitOrder(0x4395104fC82654ddEaC3ECF01AB40a1814bFb2f4));

        string[] memory names = new string[](1);
        names[0] = limitOrder.name();

        address[] memory addrs = new address[](1);
        addrs[0] = address(limitOrder);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
