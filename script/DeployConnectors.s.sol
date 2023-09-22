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
        new SynthetixPerpV3Connector(0x9863Dae3f4b5F4Ffe3A841a21565d57F2BA10E87, 0x17633A63083dbd4941891F87Bdf31B896e91e2B9, 0x579c612E4Bf390f5504DB9f76b6F5759A3172279);

        names[0] = snxV3.name();

        addrs[0] = address(snxV3);

        // connectors.updateConnectors(names, addrs);
        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
