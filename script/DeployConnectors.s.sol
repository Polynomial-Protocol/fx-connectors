// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpV3Connector} from "../src/connectors/SynthetixPerpV3.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);

        // mainnet fx-wallet connectors address
        // IConnectors connectors = IConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

        // base goerli fx-wallet connectors address
        IConnectors connectors = IConnectors(0x95325058C51Acc796E35F3D0309Ff098c4f818F1);

        // // op goerli fx-wallet connectos address
        // IConnectors connectors = IConnectors(
        //     0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2
        // );

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        SynthetixPerpV3Connector snxV3 =
        new SynthetixPerpV3Connector(0xEED61f0CB02f3B38923b1b6EAa939D5f04f431b6, 0x41A883a85b1AdE59F41d459Fa550b40fa56429DB, 0xC9ee9628f23b14483EA413C28712690E8D2dC6a3, 0x9849832a1d8274aaeDb1112ad9686413461e7101);

        names[0] = snxV3.name();

        addrs[0] = address(snxV3);

        // connectors.updateConnectors(names, addrs);
        connectors.addConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
