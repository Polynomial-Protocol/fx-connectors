// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {FeeConnector} from "../../src/base_goerli/connectors/Fee.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployFeeConnector is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);

        address usdc = 0x367Fed42283FeBC9D8A6D78c5ab62F78B6022e27;
        address fee = 0xC33897fa2693D40A6Cad2B11c3e0792D305BBa92;
        IConnectors connectors = IConnectors(0x95325058C51Acc796E35F3D0309Ff098c4f818F1);

        FeeConnector feeConnector = new FeeConnector(usdc, fee);

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        names[0] = feeConnector.name();
        addrs[0] = address(feeConnector);

        connectors.addConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
