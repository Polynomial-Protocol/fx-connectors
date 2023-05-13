// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixPerpResolver} from "../src/resolvers/SynthetixPerp.sol";

contract ResolverTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SynthetixPerpResolver resolver = new SynthetixPerpResolver();

        (, uint256 fee, uint256 liquidationPrice, uint256 totalMargin, uint256 accessibleMargin,,) = resolver.calculate(
            0x5B6BeB79E959Aac2659bEE60fE0D0885468BF886,
            0,
            -2060513923362160436,
            0x0359760336188A8189e15e78C0aC2e299DA01Fba
        );

        console2.log(fee, liquidationPrice, totalMargin, accessibleMargin);

        vm.stopBroadcast();
    }
}
