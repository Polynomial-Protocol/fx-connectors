// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpResolver} from "../src/resolvers/SynthetixPerp.sol";

contract ResolverTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SynthetixPerpResolver resolver = SynthetixPerpResolver(0x2bF91dcE25B34E80FC915339Af115e6Ca82a0883);

        (
            uint256 minKeeperFee,
            uint256 fee,
            uint256 liquidationPrice,
            uint256 totalMargin,
            uint256 accessibleMargin,
            uint256 assetPrice,
            uint8 status
        ) = resolver.calculate(
            0x2B3bb4c683BFc5239B029131EEf3B1d214478d93,
            100000000000,
            100000000000,
            0xA9Cd8d5941Ca4980ab144AD80f978d22827f9630
        );

        console2.log(fee, liquidationPrice, totalMargin, accessibleMargin);
        console2.log(minKeeperFee, assetPrice, uint256(status));

        vm.stopBroadcast();
    }
}
