// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BasicConnector} from "../../src/base/connectors/Basic.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract UpdateBasic is Script {
    address constant connector = 0x90c5D64a67425d03774439d8d37194B29C2070FA;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(connector);
        BasicConnector basic = new BasicConnector();

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        names[0] = basic.name();
        addrs[0] = address(basic);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
