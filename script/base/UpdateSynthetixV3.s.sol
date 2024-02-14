// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpV3Connector} from "../../src/base/connectors/SynthetixPerpV3.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract UpdateSpotV3 is Script {
    address constant connector = 0x90c5D64a67425d03774439d8d37194B29C2070FA;
    address constant perpMarket = 0x0A2AF931eFFd34b81ebcc57E3d3c9B1E1dE1C9Ce;
    address constant spotMarket = 0x18141523403e2595D31b22604AcB8Fc06a4CaA61;
    address constant accountModule = 0xcb68b813210aFa0373F076239Ad4803f8809e8cf;
    address constant susd = 0x09d51516F38980035153a554c26Df3C6f51a23C3;
    address constant pythNode = 0xEb38e347F24ea04ffA945a475BdD949E0c383A0F;


    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IConnectors connectors = IConnectors(connector);
        SynthetixPerpV3Connector spotV3 = new SynthetixPerpV3Connector(perpMarket, spotMarket, accountModule, susd, pythNode);

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        names[0] = spotV3.name();
        addrs[0] = address(spotV3);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
