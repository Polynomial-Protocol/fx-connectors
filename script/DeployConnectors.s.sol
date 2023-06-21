// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {MatchaConnector} from "../src/connectors/Matcha.sol";
import {BasicConnector} from "../src/connectors/Basic.sol";
import {OneInchConnector} from "../src/connectors/OneInch.sol";
import {SynthetixPerpConnector} from "../src/connectors/SynthetixPerp.sol";
import {SynthetixSpotConnector} from "../src/connectors/SynthetixSpot.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // mainnet fx-wallet connectors address
        IConnectors connectors = IConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

        // op goerli fx-wallet connectos address
        // IConnectors connectors = IConnectors(
        //     0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2
        // );

        string[] memory names = new string[](5);
        address[] memory addrs = new address[](5);
        // Basic
        MatchaConnector matcha = new MatchaConnector();
        names[0] = matcha.name();
        addrs[0] = address(matcha);

        BasicConnector basic = new BasicConnector();
        names[1] = basic.name();
        addrs[1] = address(basic);

        OneInchConnector oneInch = new OneInchConnector();
        names[2] = oneInch.name();
        addrs[2] = address(oneInch);

        SynthetixPerpConnector perp = new SynthetixPerpConnector();
        names[3] = perp.name();
        addrs[3] = address(perp);

        SynthetixSpotConnector spot = new SynthetixSpotConnector();
        names[4] = spot.name();
        addrs[4] = address(spot);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
