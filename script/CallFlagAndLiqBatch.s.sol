// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";

interface IFlagAndLiquidate {
    function flagAndLiqBatch(address, address[] calldata) external;
}

contract PlaceOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IFlagAndLiquidate fandl = IFlagAndLiquidate(
            0x805A1a35A1c58EF72Ff06a5454Dcb2C988444f71
        );
        address[] memory users = new address[](1);
        users[0] = 0x3e7e5434623830AE2C885AD23A3B783611A36381;
        fandl.flagAndLiqBatch(
            0x111BAbcdd66b1B60A20152a2D3D06d36F8B5703c,
            users
        );

        vm.stopBroadcast();
    }
}

// function submitOffchainDelayedOrderWithTracking(
//     int256 sizeDelta,
//     uint256 priceImpactDelta,
//     bytes32 trackingCode KWENTA
// ) external;
