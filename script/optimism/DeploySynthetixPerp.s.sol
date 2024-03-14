// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpConnector} from "../../src/optimism/connectors/SynthetixPerp.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployPerp is Script {
    address constant connector = 0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(connector);
        SynthetixPerpConnector perp = new SynthetixPerpConnector();

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        names[0] = perp.name();
        addrs[0] = address(perp);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
