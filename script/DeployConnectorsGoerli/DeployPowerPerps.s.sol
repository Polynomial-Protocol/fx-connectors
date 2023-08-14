// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PowerPerpConnector} from "../../src/connectors/PowerPerp.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

contract DeployConnectors is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // mainnet fx-wallet connectors address
        // IConnectors connectors = IConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

        // op goerli fx-wallet connectos address
        IConnectors connectors = IConnectors(0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2);

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        address _liquidityToken = 0xbF81F4744418ecE15453F81836a18A57F9B7C4E6;
        address _powerPerp = 0xaBB46589dFa3E22C348157Ccc6bA9388885eBCA3;
        address _shortToken = 0x8C70B8e7fC0Bbb7e208BaE8754cC696094735b76;
        address _liquidityPool = 0xAFda86a47007949226C0eaC012A4E46a3108a3A6;
        address _exchange = 0xF4F975EefEd5C7df71bcC33d99b8F6c920210262;
        PowerPerpConnector power = new PowerPerpConnector(
            _liquidityToken,
            _powerPerp,
            _shortToken,
            _liquidityPool,
            _exchange
        );

        names[0] = power.name();
        addrs[0] = address(power);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
