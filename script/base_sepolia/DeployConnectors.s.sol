// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {BasicConnector} from "../../src/base_sepolia/connectors/Basic.sol";
import {AuthConnector} from "../../src/base_sepolia/connectors/Auth.sol";
import {SynthetixPerpV3Connector} from "../../src/base_sepolia/connectors/SynthetixPerpV3.sol";
import {SynthetixSpotV3Connector} from "../../src/base_sepolia/connectors/SynthetixSpotV3.sol";
import {SynthetixStakingConnector} from "../../src/base_sepolia/connectors/SynthetixStaking.sol";

interface IConnectors {
    function addConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _connectorNames, address[] calldata _connectors) external;
}

interface ISynthetix {
    function getPreferredPool() external view returns (uint128);
}

contract DeployResolvers is Script {
    address constant connectorsAddr = 0xC891d76FED18B755Fe72FFf9ae738f8dA5DEEd16;

    // get from synthetix
    address constant perpsMarketAddr = 0x0000000000000000000000000000000000000000;
    address constant spotMarketAddr = 0x0000000000000000000000000000000000000000;
    address constant susdAddr = 0x0000000000000000000000000000000000000000;
    address constant usdcAddr = 0x0000000000000000000000000000000000000000;
    address constant susdcAddr = 0x0000000000000000000000000000000000000000;
    address constant pythNodeAddr = 0x0000000000000000000000000000000000000000;
    address constant synthetixAddr = 0x0000000000000000000000000000000000000000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        IConnectors connectors = IConnectors(connectorsAddr);
        ISynthetix synthetix = ISynthetix(synthetixAddr);
        uint128 preferredPool = synthetix.getPreferredPool();

        vm.startBroadcast(deployerPrivateKey);
        AuthConnector auth = new AuthConnector();
        BasicConnector basic = new BasicConnector();
        SynthetixPerpV3Connector perpV3 =
            new SynthetixPerpV3Connector(perpsMarketAddr, spotMarketAddr, susdAddr, pythNodeAddr);
        SynthetixSpotV3Connector spotV3 = new SynthetixSpotV3Connector(spotMarketAddr, susdAddr, usdcAddr);
        SynthetixStakingConnector staking =
            new SynthetixStakingConnector(synthetixAddr, spotMarketAddr, susdcAddr, usdcAddr, preferredPool);

        string[] memory names = new string[](5);
        address[] memory addrs = new address[](5);

        names[0] = auth.name();
        addrs[0] = address(auth);

        names[1] = basic.name();
        addrs[1] = address(basic);

        names[2] = perpV3.name();
        addrs[2] = address(perpV3);

        names[3] = spotV3.name();
        addrs[3] = address(spotV3);

        names[4] = staking.name();
        addrs[4] = address(staking);

        connectors.updateConnectors(names, addrs);
        vm.stopBroadcast();
    }
}
