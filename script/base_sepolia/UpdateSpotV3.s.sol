// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixSpotV3Connector} from "../../src/base_sepolia/connectors/SynthetixSpotV3.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract UpdateSpotV3 is Script {
    address constant connector = 0xC891d76FED18B755Fe72FFf9ae738f8dA5DEEd16;
    address constant spotMarket = 0xA4fE63F8ea9657990eA8E05Ebfa5C19a7D4d7337;
    address constant susd = 0xa89163A087fe38022690C313b5D4BBF12574637f;
    address constant usdc = 0x69980C3296416820623b3e3b30703A74e2320bC8;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(connector);
        SynthetixSpotV3Connector spotV3 = new SynthetixSpotV3Connector(spotMarket, susd, usdc);

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        names[0] = spotV3.name();
        addrs[0] = address(spotV3);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
