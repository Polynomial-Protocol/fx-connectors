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

        address admin = 0x59672D112d680CE34C20fF1507197993CC0bA430;
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
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(limitOrder), admin, data);

        SynthetixLimitOrders target = SynthetixLimitOrders(address(proxy));

        target.updatePythTimeCutoff(120); // 2 Mins
        target.updatePythDeltaCutoff(2e16); // 2%

        address[] memory markets = new address[](24);
        bytes32[] memory ids = new bytes32[](24);

        address[24] memory _markets = [
            0x5374761526175B59f1E583246E20639909E189cE, // AAVE
            0x5B6BeB79E959Aac2659bEE60fE0D0885468BF886, // APE
            0x509072A5aE4a87AC89Fc8D64D94aDCb44Bd4b88e, // ARB
            0xbB16C7B3244DFA1a6BF83Fcce3EE4560837763CD, // ATOM
            0x9De146b5663b82F44E5052dEDe2aA3Fd4CBcDC99, // AUD
            0xc203A12F298CE73E44F7d45A4f59a43DBfFe204D, // AVAX
            0x3a52b21816168dfe35bE99b7C5fc209f17a0aDb1, // AXS
            0x0940B0A96C5e1ba33AEE331a9f950Bb2a6F2Fb25, // BNB
            0x59b007E9ea8F89b069c43F8f45834d30853e3699, // BTC
            0x98cCbC721cc05E28a125943D69039B39BE6A21e9, // DOGE
            0x139F94E4f0e1101c1464a321CBA815c34d58B5D9, // DYDX
            0x2B3bb4c683BFc5239B029131EEf3B1d214478d93, // ETH
            0x87AE62c5720DAB812BDacba66cc24839440048d1, // EUR
            0x27665271210aCff4Fab08AD9Bb657E91866471F0, // FLOW
            0xC18f85A6DD3Bcd0516a1CA08d3B1f0A4E191A2C4, // FTM
            0x1dAd8808D8aC58a0df912aDC4b215ca3B93D6C49, // GBP
            0x31A1659Ca00F617E86Dc765B6494Afe70a5A9c1A, // LINK
            0x074B8F19fc91d6B2eb51143E1f186Ca0DDB88042, // MATIC
            0xC8fCd6fB4D15dD7C455373297dEF375a08942eCe, // NEAR
            0x442b69937a0daf9D46439a71567fABE6Cb69FBaf, // OP
            0x0EA09D97b4084d859328ec4bF8eBCF9ecCA26F1D, // SOL
            0x4308427C463CAEAaB50FFf98a9deC569C31E4E87, // UNI
            0xdcB8438c979fA030581314e5A5Df42bbFEd744a0, // XAG
            0x549dbDFfbd47bD5639f9348eBE82E63e2f9F777A // XAU
        ];
        bytes32[24] memory _ids = [
            bytes32(0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445), // AAVE
            bytes32(0x15add95022ae13563a11992e727c91bdb6b55bc183d9d747436c80a483d8c864), // APE
            bytes32(0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5), // ARB
            bytes32(0xb00b60f88b03a6a625a8d1c048c3f66653edf217439983d037e7222c4e612819), // ATOM
            bytes32(0x67a6f93030420c1c9e3fe37c1ab6b77966af82f995944a9fefce357a22854a80), // AUD
            bytes32(0x93da3352f9f1d105fdfe4971cfa80e9dd777bfc5d0f683ebb6e1294b92137bb7), // AVAX
            bytes32(0xb7e3904c08ddd9c0c10c6d207d390fd19e87eb6aab96304f571ed94caebdefa0), // AXS
            bytes32(0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f), // BNB
            bytes32(0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43), // BNB
            bytes32(0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c), // DOGE
            bytes32(0x6489800bb8974169adfe35937bf6736507097d13c190d760c557108c7e93a81b), // DOGE
            bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace), // ETH
            bytes32(0xa995d00bb36a63cef7fd2c287dc105fc8f3d93779f062f09551b0af3e81ec30b), // EUR
            bytes32(0x2fb245b9a84554a0f15aa123cbb5f64cd263b59e9a87d80148cbffab50c69f30), // FLOW
            bytes32(0x5c6c0d2386e3352356c3ab84434fafb5ea067ac2678a38a338c4a69ddc4bdb0c), // FTM
            bytes32(0x84c2dde9633d93d1bcad84e7dc41c9d56578b7ec52fabedc1f335d673df0a7c1), // GBP
            bytes32(0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221), // LINK
            bytes32(0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52), // MATIC
            bytes32(0xc415de8d2eba7db216527dff4b60e8f3a5311c740dadb233e13e12547e226750), // NEAR
            bytes32(0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf), // OP
            bytes32(0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d), // SOL
            bytes32(0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501), // UNI
            bytes32(0xf2fb02c32b055c805e7238d628e5e9dadef274376114eb1f012337cabe93871e), // XAG
            bytes32(0x765d2ba906dbc32ca17cc11f5310a89e9ee1f6420508c63861f2f8ba4ee34bb2) // XAU
        ];

        for (uint256 i = 0; i < 24; i++) {
            markets[i] = _markets[i];
            ids[i] = _ids[i];
        }

        target.updatePythOracleIds(markets, ids);

        vm.stopBroadcast();
    }
}
