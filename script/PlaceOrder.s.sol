// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {SynthetixPerpConnector} from "../src/connectors/SynthetixPerp.sol";

interface IPerpsV2Market {
    function transferMargin(int256 marginDelta) external;

    function withdrawAllMargin() external;

    function modifyPosition(
        int256 sizeDelta,
        uint256 priceImpactDelta
    ) external;

    function modifyPositionWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function closePosition(uint256 priceImpactDelta) external;

    function closePositionWithTracking(
        uint256 priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function submitDelayedOrder(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 desiredTimeDelta
    ) external;

    function submitDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        uint256 desiredTimeDelta,
        bytes32 trackingCode
    ) external;

    function cancelDelayedOrder(address account) external;

    function executeDelayedOrder(address account) external;

    function submitOffchainDelayedOrder(
        int256 sizeDelta,
        uint256 priceImpactDelta
    ) external;

    function submitOffchainDelayedOrderWithTracking(
        int256 sizeDelta,
        uint256 priceImpactDelta,
        bytes32 trackingCode
    ) external;

    function cancelOffchainDelayedOrder(address account) external;

    function executeOffchainDelayedOrder(
        address account,
        bytes[] calldata priceUpdateData
    ) external payable;

    function assetPrice() external view returns (uint256 price, bool invalid);

    function baseAsset() external view returns (bytes32 key);

    function remainingMargin(
        address account
    ) external view returns (uint256 marginRemaining, bool invalid);
}

interface ISynthetixConnector {
    function trade(address market, int256 sizeDelta, uint256 slippage) external;

    function addMargin(
        address market,
        uint256 amt,
        uint256 getId,
        uint256 setId
    ) external;
}

contract PlaceOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IPerpsV2Market perp = IPerpsV2Market(
            0x111BAbcdd66b1B60A20152a2D3D06d36F8B5703c
        );
        perp.transferMargin(42e16);

        // perp.submitOffchainDelayedOrder(1e17, 1900e18);
        perp.submitOffchainDelayedOrder(14e17, 1900e18);
        // perp.submitOffchainDelayedOrder(2e16, 1900e18);

        vm.stopBroadcast();
    }
}
