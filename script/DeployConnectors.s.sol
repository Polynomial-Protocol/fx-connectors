// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {AaveConnector} from "../src/connectors/Aave.sol";

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

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        AaveConnector aave = new AaveConnector();
        names[0] = aave.name();
        addrs[0] = address(aave);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
