// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";

import {SynthetixLimitOrders} from "../src/automations/SynthetixAdvancedOrders.sol";

contract UpdatePythOracleIds is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SynthetixLimitOrders target = SynthetixLimitOrders(payable(0x7634E43aA3f446C8d9D5014d609355F728361075));

        address[] memory markets = new address[](17);
        bytes32[] memory ids = new bytes32[](17);

        address[17] memory _markets = [
            0xF9DD29D2Fd9B38Cd90E390C797F1B7E0523f43A9, // ADA
            0x9615B6BfFf240c44D3E33d0cd9A11f563a2e8D8B, // APT
            0x96690aAe7CB7c4A9b5Be5695E94d72827DeCC33f, // BCH
            0xa1Ace9ce6862e865937939005b1a6c5aC938A11F, // BLUR
            0xD5fBf7136B86021eF9d0BE5d798f948DcE9C0deA, // CRV
            0x8B9B5f94aac2316f048025B3cBe442386E85984b, // DOT
            0x2C5E2148bF3409659967FE3684fd999A76171235, // FIL
            0x5ed8D0946b59d015f5A60039922b870537d43689, // FLOKI
            0x33d4613639603c845e61A02cd3D2A78BE7d513dc, // GMX
            0x852210F0616aC226A486ad3387DBF990e690116A, // INJ
            0xaa94C874b91ef16C8B56A1c5B2F34E39366bD484, // LDO
            0xB25529266D9677E9171BEaf333a0deA506c5F99A, // LTC
            0x3D3f34416f60f77A0a6cC8e32abe45D32A7497cb, // PEPE
            0x69F5F465a46f324Fb7bf3fD7c0D5c00f7165C7Ea, // SHIB
            0x09F9d7aaa6Bef9598c3b676c0E19C9786Aa566a8, // SUI
            0x031A448F59111000b96F016c37e9c71e57845096, // TRX
            0x6110DF298B411a46d6edce72f5CAca9Ad826C1De // XRP
        ];

        bytes32[17] memory _ids = [
            bytes32(0x2a01deaec9e51a579277b34b122399984d0bbf57e2458a7e42fecd2829867a0d), // ADA
            bytes32(0x03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5), // APT
            bytes32(0x3dd2b63686a450ec7290df3a1e0b583c0481f651351edfa7636f39aed55cf8a3), // BCH
            bytes32(0x856aac602516addee497edf6f50d39e8c95ae5fb0da1ed434a8c2ab9c3e877e9), // BLUR
            bytes32(0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8), // CRV
            bytes32(0xca3eed9b267293f6595901c734c7525ce8ef49adafe8284606ceb307afa2ca5b), // DOT
            bytes32(0x150ac9b959aee0051e4091f0ef5216d941f590e1c5e7f91cf7635b5c11628c0e), // FIL
            bytes32(0x6b1381ce7e874dc5410b197ac8348162c0dd6c0d4c9cd6322672d6c2b1d58293), // FLOKI
            bytes32(0xb962539d0fcb272a494d65ea56f94851c2bcf8823935da05bd628916e2e9edbf), // GMX
            bytes32(0x7a5bc1d2b56ad029048cd63964b3ad2776eadf812edc1a43a31406cb54bff592), // INJ
            bytes32(0xc63e2a7f37a04e5e614c07238bedb25dcc38927fba8fe890597a593c0b2fa4ad), // LDO
            bytes32(0x6e3f3fa8253588df9326580180233eb791e03b443a3ba7a1d892e73874e19a54), // LTC
            bytes32(0xd69731a2e74ac1ce884fc3890f7ee324b6deb66147055249568869ed700882e4), // PEPE
            bytes32(0xf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a), // SHIB
            bytes32(0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744), // SUI
            bytes32(0x67aed5a24fdad045475e7195c98a98aea119c763f272d4523f5bac93a4f33c2b), // TRX
            bytes32(0xec5d399846a9209f3fe5881d70aae9268c94339ff9817e8d18ff19fa05eea1c8) // XRP
        ];

        for (uint256 i = 0; i < 17; i++) {
            markets[i] = _markets[i];
            ids[i] = _ids[i];
        }

        target.updatePythOracleIds(markets, ids);

        vm.stopBroadcast();
    }
}
