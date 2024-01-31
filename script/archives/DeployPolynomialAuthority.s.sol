// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {PolynomialAuthority} from "../../src/common/utils/PolynomialAuthority.sol";

contract DeployPolynomialAuthority is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_NEW");
        vm.startBroadcast(deployerPrivateKey);
        new PolynomialAuthority();
        vm.stopBroadcast();
    }
}
