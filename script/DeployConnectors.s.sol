// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BasicConnector} from "../src/connectors/Basic.sol";
import {SynthetixPerpConnector} from "../src/connectors/SynthetixPerp.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(0x3fE6Bb6275A00b235E56bA99100022Eba00816A9);

        BasicConnector basic = new BasicConnector();
        SynthetixPerpConnector synthetixPerp = new SynthetixPerpConnector();

        string[] memory names = new string[](2);
        names[0] = basic.name();
        names[1] = synthetixPerp.name();

        address[] memory addrs = new address[](2);
        addrs[0] = address(basic);
        addrs[1] = address(synthetixPerp);

        connectors.addConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
