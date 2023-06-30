// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PowerPerpConnector} from "../../src/connectors/PowerPerp.sol";

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

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        address _liquidityToken = 0xcCCc5B080698de14093745d16301090AB43ef50F;
        address _powerPerp = 0xAC49E93cf24D2dFB058F10582938C66cD0046e6A;
        address _shortToken = 0xF0806D460FD672ec30C4e133fD8Eb7a125Bef04B;
        address _liquidityPool = 0x3a93068c82050C5336aBd951Ea3888ef6D9e5d6e;
        address _exchange = 0x489709F24D265Bc2dD6494Da26fBc8DD67243E11;
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
