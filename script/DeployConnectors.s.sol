// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AuthConnector} from "../src/connectors/Auth.sol";
import {BasicConnector} from "../src/connectors/Basic.sol";

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

        string[] memory names = new string[](2);
        address[] memory addrs = new address[](2);
        
        AuthConnector auth = new AuthConnector();
        BasicConnector basic = new BasicConnector();

        names[0] = auth.name();
        names[1] = basic.name();

        addrs[0] = address(auth);
        addrs[1] = address(basic);

        // connectors.updateConnectors(names, addrs);
        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
