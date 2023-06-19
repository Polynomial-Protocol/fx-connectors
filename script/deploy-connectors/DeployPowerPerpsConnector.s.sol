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
        // IConnectors connectors = IConnectors(
        //     0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA
        // );

        // op goerli fx-wallet connectos address
        IConnectors connectors = IConnectors(
            0x2BDC91973bfB5B16a5652520e3960Fd68D7be5C2
        );

        string[] memory names = new string[](1);
        address[] memory addrs = new address[](1);

        address PowerPerp = 0x71632c8180710f81BF24FC196754FC52c3Fb2741;
        address ShortToken = 0xB413AB8CeAaa33507E5382Dd979a0b823B23FE43;
        address Exchange = 0xCfC9dBF5FC710Ef05ee52819868329D0eAE3c08B;
        address LiquidityToken = 0x1E73374BCf29e29230157aCc0EDfc075Ee7BF2f1;
        address LiquidityPool = 0xcE2632437717218fE7da94437c5FcbD3aBBE81c6;

        PowerPerpConnector matcha = new PowerPerpConnector(
            LiquidityToken,
            PowerPerp,
            ShortToken,
            LiquidityPool,
            Exchange
        );
        names[0] = matcha.name();
        addrs[0] = address(matcha);

        connectors.updateConnectors(names, addrs);

        vm.stopBroadcast();
    }
}
