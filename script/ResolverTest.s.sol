// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpResolver} from "../src/resolvers/SynthetixPerp.sol";

contract ResolverTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SynthetixPerpResolver resolver = SynthetixPerpResolver(0x80564F8d8E562A753AFCEB7FAD3983747ADfe649);

        (uint256 fee, uint256 liquidationPrice, uint256 totalMargin, uint256 accessibleMargin,,) = resolver.calculate(
            0x5B6BeB79E959Aac2659bEE60fE0D0885468BF886, 60e18, 6e18, 0x554ed966Ad76076A8C4dAc4f3506B025e8c5bC24
        );

        console2.log(fee, liquidationPrice, totalMargin, accessibleMargin);

        vm.stopBroadcast();
    }
}
