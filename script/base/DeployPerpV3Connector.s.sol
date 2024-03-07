// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpV3Connector} from "../../src/base/connectors/SynthetixPerpV3.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployPerpV3 is Script {
    address constant connector = 0x2d4937ED79D434290c4baeA6d390b78c0bf907d8;
    address constant perpsMarketAddr = 0x0A2AF931eFFd34b81ebcc57E3d3c9B1E1dE1C9Ce;
    address constant spotMarketAddr = 0x18141523403e2595D31b22604AcB8Fc06a4CaA61;
    address constant susdAddr = 0x09d51516F38980035153a554c26Df3C6f51a23C3;
    address constant pythNodeAddr = 0xEb38e347F24ea04ffA945a475BdD949E0c383A0F;
    address constant accountNFT = 0xcb68b813210aFa0373F076239Ad4803f8809e8cf;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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
