// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {SynthetixLimitOrders} from "../src/automations/SynthetixAdvancedOrders.sol";
import {TransparentUpgradeableProxy} from "../src/proxy/TransparentUpgradeProxy.sol";

import {IPyth} from "../src/interfaces/IPyth.sol";

contract DeployLimitOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = 0x657167F589aA788A52979d4F40f74B6d82aAA6c5;
        address deployer = vm.addr(deployerPrivateKey);
        address feeReceipient = 0x7cb6bF3e7395965b2162A7C2e6876720C20012d6;

        SynthetixLimitOrders limitOrder = new SynthetixLimitOrders();
        bytes memory data = abi.encodeWithSelector(
            SynthetixLimitOrders.initialize.selector,
            IPyth(0xff1a0f4744e8582DF1aE09D5611b887B6a12925C),
            deployer,
            feeReceipient,
            2e18, // 2 sUSD
            3e14 // 3 bps
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(limitOrder),
            admin,
            data
        );

        SynthetixLimitOrders target = SynthetixLimitOrders(payable(address(proxy)));

        target.updatePythTimeCutoff(120); // 2 Mins
        target.updatePythDeltaCutoff(2e16); // 2%

        address[] memory markets = new address[](23);
        bytes32[] memory ids = new bytes32[](23);

        // Market addresses on mainnet op
        // address[24] memory _markets = [
        //     0x5374761526175B59f1E583246E20639909E189cE, // AAVE
        //     0x5B6BeB79E959Aac2659bEE60fE0D0885468BF886, // APE
        //     0x509072A5aE4a87AC89Fc8D64D94aDCb44Bd4b88e, // ARB
        //     0xbB16C7B3244DFA1a6BF83Fcce3EE4560837763CD, // ATOM
        //     0x9De146b5663b82F44E5052dEDe2aA3Fd4CBcDC99, // AUD
        //     0xc203A12F298CE73E44F7d45A4f59a43DBfFe204D, // AVAX
        //     0x3a52b21816168dfe35bE99b7C5fc209f17a0aDb1, // AXS
        //     0x0940B0A96C5e1ba33AEE331a9f950Bb2a6F2Fb25, // BNB
        //     0x59b007E9ea8F89b069c43F8f45834d30853e3699, // BTC
        //     0x98cCbC721cc05E28a125943D69039B39BE6A21e9, // DOGE
        //     0x139F94E4f0e1101c1464a321CBA815c34d58B5D9, // DYDX
        //     0x2B3bb4c683BFc5239B029131EEf3B1d214478d93, // ETH
        //     0x87AE62c5720DAB812BDacba66cc24839440048d1, // EUR
        //     0x27665271210aCff4Fab08AD9Bb657E91866471F0, // FLOW
        //     0xC18f85A6DD3Bcd0516a1CA08d3B1f0A4E191A2C4, // FTM
        //     0x1dAd8808D8aC58a0df912aDC4b215ca3B93D6C49, // GBP
        //     0x31A1659Ca00F617E86Dc765B6494Afe70a5A9c1A, // LINK
        //     0x074B8F19fc91d6B2eb51143E1f186Ca0DDB88042, // MATIC
        //     0xC8fCd6fB4D15dD7C455373297dEF375a08942eCe, // NEAR
        //     0x442b69937a0daf9D46439a71567fABE6Cb69FBaf, // OP
        //     0x0EA09D97b4084d859328ec4bF8eBCF9ecCA26F1D, // SOL
        //     0x4308427C463CAEAaB50FFf98a9deC569C31E4E87, // UNI
        //     0xdcB8438c979fA030581314e5A5Df42bbFEd744a0, // XAG
        //     0x549dbDFfbd47bD5639f9348eBE82E63e2f9F777A // XAU
        // ];

        // Market addresses on op goerli
        address[23] memory _markets = [
            0x3410215D8A0BD57dAc5911785F2A832402D5c828, // AAVE
            0x5B6BeB79E959Aac2659bEE60fE0D0885468BF886, // APE
            // ARB not supported on goerli
            0xcCdc541a12CA359216913c1893C080d951874346, // ATOM
            0x95b78e2E07090587754f3088Ef8a8232f1Ab7E47, // AUD
            0xe140356AB1F0558e020610C9C6BccdAA4FDDE2f4, // AVAX
            0x9CE0556a563f18AeA0E89F407B0b1710F095956f, // AXS
            0x307072038D47bAE97CaE56C0eA87F2a5f0CD8389, // BNB
            0xd5844EA3701a4507C27ebc5EBA733E1Aa2915B31, // BTC
            0x3A4D5262b10C670a06550FCf7346cd408343B3FB, // DOGE
            0xb97e868a340BA00C10557c234C9F17cC41B0f667, // DYDX
            0x111BAbcdd66b1B60A20152a2D3D06d36F8B5703c, // ETH
            0x9C54994933205E33628A8870c05AFF0878b1A56b, // EUR
            0xcFA34059b55E1a1c820e4D62A6CA4f8e00522eBB, // FLOW
            0x70362529cCfF83f586EB48e978eF3b60384cE050, // FTM
            0x534181B37bdaFdD1E28104Bc5117184F40e1056F, // GBP
            0x6141dcfF3494921e1C4Cdb115daD20C6656f6EFA, // LINK
            0x7bBEa20899d358ed6d877f32af1BCb525a5fCF31, // MATIC
            0xf503e527854b510C1952425d4b61c6bba40028CE, // NEAR
            0x4926222EDDa82965Aa08080f281928f8cba5922A, // OP
            0x62068eBDCEbcB0eB984aBfEa4c7f9A244050e0Ca, // SOL
            0xaF11B4281259D7Ae31F945a2911Ba75347C2799d, // UNI
            0x78D1232449387571D652E2a893DC0feaC6E92436, // XAG
            0xcC312F5Bac1C36CC70AbcbE76De913633Af88FFB // XAU
        ];

        // pyth ids for op mainnet
        // bytes32[24] memory _ids = [
        //     bytes32(
        //         0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445
        //     ), // AAVE
        //     bytes32(
        //         0x15add95022ae13563a11992e727c91bdb6b55bc183d9d747436c80a483d8c864
        //     ), // APE
        //     bytes32(
        //         0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5
        //     ), // ARB
        //     bytes32(
        //         0xb00b60f88b03a6a625a8d1c048c3f66653edf217439983d037e7222c4e612819
        //     ), // ATOM
        //     bytes32(
        //         0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80
        //     ), // AUD
        //     bytes32(
        //         0x93da3352f9f1d105fdfe4971cfa80e9dd777bfc5d0f683ebb6e1294b92137bb7
        //     ), // AVAX
        //     bytes32(
        //         0xb7e3904c08ddd9c0c10c6d207d390fd19e87eb6aab96304f571ed94caebdefa0
        //     ), // AXS
        //     bytes32(
        //         0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f
        //     ), // BNB
        //     bytes32(
        //         0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43
        //     ), // BTC
        //     bytes32(
        //         0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c
        //     ), // DOGE
        //     bytes32(
        //         0x6489800bb8974169adfe35937bf6736507097d13c190d760c557108c7e93a81b
        //     ), // DYDX
        //     bytes32(
        //         0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
        //     ), // ETH
        //     bytes32(
        //         0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b
        //     ), // EUR
        //     bytes32(
        //         0x2fb245b9a84554a0f15aa123cbb5f64cd263b59e9a87d80148cbffab50c69f30
        //     ), // FLOW
        //     bytes32(
        //         0x5c6c0d2386e3352356c3ab84434fafb5ea067ac2678a38a338c4a69ddc4bdb0c
        //     ), // FTM
        //     bytes32(
        //         0x84c2dde9633d93d1bcad84e7dc41c9d56578b7ec52fabedc1f335d673df0a7c1
        //     ), // GBP
        //     bytes32(
        //         0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221
        //     ), // LINK
        //     bytes32(
        //         0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52
        //     ), // MATIC
        //     bytes32(
        //         0xc415de8d2eba7db216527dff4b60e8f3a5311c740dadb233e13e12547e226750
        //     ), // NEAR
        //     bytes32(
        //         0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf
        //     ), // OP
        //     bytes32(
        //         0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d
        //     ), // SOL
        //     bytes32(
        //         0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501
        //     ), // UNI
        //     bytes32(
        //         0xf2fb02c32b055c805e7238d628e5e9dadef274376114eb1f012337cabe93871e
        //     ), // XAG
        //     bytes32(
        //         0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2
        //     ) // XAU
        // ];

        // pyth ids for op goerli
        bytes32[23] memory _ids = [
            bytes32(0xd6b3bc030a8bbb7dd9de46fb564c34bb7f860dead8985eb16a49cdc62f8ab3a5), // AAVE
            bytes32(0xcb1743d0e3e3eace7e84b8230dc082829813e3ab04e91b503c08e9a441c0ea8b), // APE
            // ARB not supported by synthetix on op goerli
            bytes32(0x61226d39beea19d334f17c2febce27e12646d84675924ebb02b9cdaea68727e3), // ATOM
            bytes32(0x2646ca1e1186fd2bb48b2ab3effa841d233b7e904b2caebb19c8030784a89c97), // AUD
            bytes32(0xd7566a3ba7f7286ed54f4ae7e983f4420ae0b1e0f3892e11f9c4ab107bbad7b9), // AVAX
            bytes32(0xb327d9cf0ecd793a175fa70ac8d2dc109d4462758e556962c4a87b02ec4f3f15), // AXS
            bytes32(0xecf553770d9b10965f8fb64771e93f5690a182edc32be4a3236e0caaa6e0581a), // BNB
            bytes32(0xf9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b), // BTC
            bytes32(0x31775e1d6897129e8a84eeba975778fb50015b88039e9bc140bbd839694ac0ae), // DOGE
            bytes32(0x05a934cb3bbadef93b525978ab5bd3d5ce3b8fc6717b9ea182a688c5d8ee8e02), // DYDX
            bytes32(0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6), // ETH
            bytes32(0xc1b12769f6633798d45adfd62bfc70114839232e2949b01fb3d3f927d2606154), // EUR
            bytes32(0xaa67a6594d0e1578faa3bba80bec5b31e461b945e4fbab59eeab38ece09335fb), // FLOW
            bytes32(0x9b7bfd7654cbb80099d5edc0a29159afc9e9b4636c811cf8c3b95bd11dd8e3dd), // FTM
            bytes32(0xbcbdc2755bd74a2065f9d3283c2b8acbd898e473bdb90a6764b3dbd467c56ecd), // GBP
            bytes32(0x83be4ed61dd8a3518d198098ce37240c494710a7b9d85e35d9fceac21df08994), // LINK
            bytes32(0xd2c2c1f2bba8e0964f9589e060c2ee97f5e19057267ac3284caef3bd50bd2cb5), // MATIC
            bytes32(0x27e867f0f4f61076456d1a73b14c7edc1cf5cef4f4d6193a33424288f11bd0f4), // NEAR
            bytes32(0x71334dcd37620ce3c33e3bafef04cc80dec083042e49b734315b36d1aad7991f), // OP
            bytes32(0xfe650f0367d4a7ef9815a593ea15d36593f0643aaaf0149bb04be67ab851decd), // SOL
            bytes32(0x64ae1fc7ceacf2cd59bee541382ff3770d847e63c40eb6cf2413e7de5e93078a), // UNI
            bytes32(0x321ba4d608fa75ba76d6d73daa715abcbdeb9dba02257f05a1b59178b49f599b), // XAG
            bytes32(0x30a19158f5a54c0adf8fb7560627343f22a1bc852b89d56be1accdc5dbf96d0e) // XAU
        ];

        for (uint256 i = 0; i < 23; i++) {
            markets[i] = _markets[i];
            ids[i] = _ids[i];
        }

        target.updatePythOracleIds(markets, ids);

        vm.stopBroadcast();
    }
}
