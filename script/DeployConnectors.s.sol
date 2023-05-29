// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BasicConnector} from "../src/connectors/Basic.sol";
import {SynthetixPerpConnector} from "../src/connectors/SynthetixPerp.sol";
import {SynthetixSpotConnector} from "../src/connectors/SynthetixSpot.sol";
import {SynthetixAdvancedOrdersConnector} from "../src/connectors/SynthetixAdvancedOrders.sol";
import {SynthetixPerpLimitOrderConnector} from "../src/connectors/SynthetixPerpLimitOrder.sol";
import {OneInchConnector} from "../src/connectors/OneInch.sol";
import {MatchaConnector} from "../src/connectors/Matcha.sol";

interface IConnectors {
    function addConnectors(
        string[] calldata _connectorNames,
        address[] calldata _connectors
    ) external;

    function updateConnectors(
        string[] calldata _connectorNames,
        address[] calldata _connectors
    ) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // mainnet fx-wallet connectors address
        // IConnectors connectors = IConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

        // op goerli fx-wallet connectos address
        IConnectors connectors = IConnectors(
            0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2
        );

        string[] memory names = new string[](4);
        address[] memory addrs = new address[](4);
        // Basic
        BasicConnector base = new BasicConnector();
        names[0] = base.name();
        addrs[0] = address(base);

        // check address of dynamic gas fee module
        SynthetixPerpConnector perp = new SynthetixPerpConnector();
        names[1] = perp.name();
        addrs[1] = address(perp);

        // Synthetix Spot
        SynthetixSpotConnector spot = new SynthetixSpotConnector();
        names[2] = spot.name();
        addrs[2] = address(spot);

        // SynthetixAdvancedOrders
        SynthetixPerpLimitOrderConnector limit = new SynthetixPerpLimitOrderConnector();
        names[3] = limit.name();
        addrs[3] = address(limit);

        // don't work on testnets
        // Matcha
        // One Inch

        connectors.addConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
