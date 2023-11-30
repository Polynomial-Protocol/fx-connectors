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
        new SynthetixPerpV3Connector(0x75c43165ea38cB857C45216a37C5405A7656673c, 0x26f3EcFa0Aa924649cfd4b74C57637e910A983a4, 0xa89163A087fe38022690C313b5D4BBF12574637f, 0xEa7a8f0fDD16Ccd46BA541Fb657a0A7FD7E36261);

        names[0] = snxV3.name();

        addrs[0] = address(snxV3);

        // connectors.updateConnectors(names, addrs);
        connectors.addConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
