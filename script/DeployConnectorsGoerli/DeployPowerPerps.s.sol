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

        address _liquidityToken = 0x4A1d965830AB0b9D14265Cb55BeAc2330e915885;
        address _powerPerp = 0xD790bEF52346a36857E63490303417956364A2ef;
        address _shortToken = 0x2fdB368781e66b5966d2fBb32dd6A52BE20923e8;
        address _liquidityPool = 0x09e3125e3dB534a8A5fD82C0FDd5de20e5007b84;
        address _exchange = 0x666598E957CB19bF0DF81F0E3B70782DED66fC81;
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
