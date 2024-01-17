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

contract DeployConnectors is Script {
    address constant connectorsAddr = 0xC891d76FED18B755Fe72FFf9ae738f8dA5DEEd16;

    // get from synthetix
    address constant perpsMarketAddr = 0xE6C5f05C415126E6b81FCc3619f65Db2fCAd58D0;
    address constant spotMarketAddr = 0xA4fE63F8ea9657990eA8E05Ebfa5C19a7D4d7337;
    address constant susdAddr = 0xa89163A087fe38022690C313b5D4BBF12574637f;
    address constant usdcAddr = 0x69980C3296416820623b3e3b30703A74e2320bC8;
    address constant susdcAddr = 0x434Aa3FDb11798EDaB506D4a5e48F70845a66219;
    address constant pythNodeAddr = 0xBf01fE835b3315968bbc094f50AE3164e6d3D969;
    address constant synthetixAddr = 0xF4Df9Dd327Fd30695d478c3c8a2fffAddcdD0d31;

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

        connectors.addConnectors(names, addrs);
        vm.stopBroadcast();
    }
}
