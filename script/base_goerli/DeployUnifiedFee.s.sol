// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {TransparentUpgradeableProxy} from "../../src/common/proxy/TransparentUpgradeProxy.sol";
import {UnifiedFee} from "../../src/common/automations/UnifiedFee.sol";

contract DeployUnifiedFee is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);
        address admin = 0x7e9D57927022A6cD8CBcddaaB7AA302Ab494a439;

        address usdc = 0x367Fed42283FeBC9D8A6D78c5ab62F78B6022e27;
        address list = 0x04D7BA4C177C2FB3a78f9057F745c3822da7B391;
        address chainlink = 0xcD2A119bD1F7DF95d706DE6F2057fDD45A0503E2;

        UnifiedFee fee = new UnifiedFee(usdc, list, chainlink);
        bytes memory data = abi.encodeWithSelector(UnifiedFee.initialize.selector, deployer);
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(fee), admin, data);

        UnifiedFee target = UnifiedFee(payable(address(proxy)));

        uint64[] memory actions = new uint64[](14);

        for (uint64 i = 0; i < 14; i++) {
            actions[i] = i + 1;
        }

        UnifiedFee.Cost[] memory costs = new UnifiedFee.Cost[](14);

        costs[0] = UnifiedFee.Cost(950, 360_000); // ID - 1; addCollateral; 0x8d300818
        costs[1] = UnifiedFee.Cost(860, 500_000); // ID - 2; buy; 0x2e07e15d
        costs[2] = UnifiedFee.Cost(570, 900_000); // ID - 3; close; 0xbc5ab866
        costs[3] = UnifiedFee.Cost(240, 320_000); // ID - 4; createAccount; 0xcadb09a5
        costs[4] = UnifiedFee.Cost(432, 29_121); // ID - 5; disableAuth; 0x6ee94a9b
        costs[5] = UnifiedFee.Cost(608, 80_997); // ID - 6; enableAuth; 0x0bf62078
        costs[6] = UnifiedFee.Cost(1120, 675_000); // ID - 7; long; 0xcc1e126c
        costs[7] = UnifiedFee.Cost(850, 600_000); // ID - 8; removeCollateral; 0x2d34d7b6
        costs[8] = UnifiedFee.Cost(1000, 750_000); // ID - 9; short; 0xfa9307cd
        costs[9] = UnifiedFee.Cost(64, 48_000); // ID - 10; toggleBeta; 0x16ad2ac3
        costs[10] = UnifiedFee.Cost(700, 693_000); // ID - 11; unwrapUSDC; 0xd5483ca9
        costs[11] = UnifiedFee.Cost(27500, 360_000); // ID - 12; updateOracle; 0xfcd7eef1
        costs[12] = UnifiedFee.Cost(1268, 45_000); // ID - 13; withdraw; 0x4bd3ab82
        costs[13] = UnifiedFee.Cost(684, 720_000); // ID - 14; wrapUSDC; 0xd312045d

        target.setCosts(actions, costs);

        vm.stopBroadcast();
    }
}
