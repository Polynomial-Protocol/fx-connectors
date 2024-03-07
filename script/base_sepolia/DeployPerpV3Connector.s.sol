// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpV3Connector} from "../../src/base_sepolia/connectors/SynthetixPerpV3.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployPerpV3 is Script {
    address constant connector = 0xC891d76FED18B755Fe72FFf9ae738f8dA5DEEd16;
    address constant perpsMarketAddr = 0xE6C5f05C415126E6b81FCc3619f65Db2fCAd58D0;
    address constant spotMarketAddr = 0xA4fE63F8ea9657990eA8E05Ebfa5C19a7D4d7337;
    address constant susdAddr = 0xa89163A087fe38022690C313b5D4BBF12574637f;
    address constant pythNodeAddr = 0xBf01fE835b3315968bbc094f50AE3164e6d3D969;
    address constant accountNFT = 0x87f578681CDE29F0701E7274708E1A67Ee9eEf94;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(connector);
        SynthetixPerpV3Connector perpV3 =
            new SynthetixPerpV3Connector(perpsMarketAddr, spotMarketAddr, susdAddr, pythNodeAddr, accountNFT);

        // string[] memory names = new string[](1);
        // address[] memory addrs = new address[](1);

        // names[0] = perpV3.name();
        // addrs[0] = address(perpV3);

        // connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
