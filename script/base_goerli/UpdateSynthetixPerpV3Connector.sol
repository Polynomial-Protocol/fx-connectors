// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpV3Connector} from "../../src/base_goerli/connectors/SynthetixPerpV3.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        IConnectors connectors = IConnectors(0x95325058C51Acc796E35F3D0309Ff098c4f818F1);

        address perpsMarketAddr = 0x75c43165ea38cB857C45216a37C5405A7656673c;
        address spotMarketAddr = 0x26f3EcFa0Aa924649cfd4b74C57637e910A983a4;
        address susdAddr = 0xa89163A087fe38022690C313b5D4BBF12574637f;
        address pythNodeAddr = 0xEa7a8f0fDD16Ccd46BA541Fb657a0A7FD7E36261;

        vm.startBroadcast(deployerPrivateKey);

        SynthetixPerpV3Connector perpV3 =
            new SynthetixPerpV3Connector(perpsMarketAddr, spotMarketAddr, susdAddr, pythNodeAddr);

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        names[0] = perpV3.name();
        addrs[0] = address(perpV3);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
