// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Script} from "forge-std/Script.sol";

import {SynthetixLimitOrders} from "../../src/common/automations/SynthetixAdvancedOrders.sol";

contract UpdatePythOracleIds is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SynthetixLimitOrders target = SynthetixLimitOrders(payable(0x7634E43aA3f446C8d9D5014d609355F728361075));

        address[] memory markets = new address[](69);
        bytes32[] memory ids = new bytes32[](69);

        address[69] memory _markets = [
            0x2B3bb4c683BFc5239B029131EEf3B1d214478d93, // ETH
            0x59b007E9ea8F89b069c43F8f45834d30853e3699, // BTC
            0x509072A5aE4a87AC89Fc8D64D94aDCb44Bd4b88e, // ARB
            0x442b69937a0daf9D46439a71567fABE6Cb69FBaf, // OP
            0xc203A12F298CE73E44F7d45A4f59a43DBfFe204D, // AVAX
            0x139F94E4f0e1101c1464a321CBA815c34d58B5D9, // DYDX
            0x5B6BeB79E959Aac2659bEE60fE0D0885468BF886, // APE
            0x074B8F19fc91d6B2eb51143E1f186Ca0DDB88042, // MATIC
            0x0940B0A96C5e1ba33AEE331a9f950Bb2a6F2Fb25, // BNB
            0x0EA09D97b4084d859328ec4bF8eBCF9ecCA26F1D, // SOL
            0x31A1659Ca00F617E86Dc765B6494Afe70a5A9c1A, // LINK
            0x98cCbC721cc05E28a125943D69039B39BE6A21e9, // DOGE
            0x5374761526175B59f1E583246E20639909E189cE, // AAVE
            0x4308427C463CAEAaB50FFf98a9deC569C31E4E87, // UNI
            0x96690aAe7CB7c4A9b5Be5695E94d72827DeCC33f, // BCH
            0xB25529266D9677E9171BEaf333a0deA506c5F99A, // LTC
            0x33d4613639603c845e61A02cd3D2A78BE7d513dc, // GMX
            0xbB16C7B3244DFA1a6BF83Fcce3EE4560837763CD, // ATOM
            0x9615B6BfFf240c44D3E33d0cd9A11f563a2e8D8B, // APT
            0x3a52b21816168dfe35bE99b7C5fc209f17a0aDb1, // AXS
            0x2C5E2148bF3409659967FE3684fd999A76171235, // FIL
            0xaa94C874b91ef16C8B56A1c5B2F34E39366bD484, // LDO
            0xC8fCd6fB4D15dD7C455373297dEF375a08942eCe, // NEAR
            0xD5fBf7136B86021eF9d0BE5d798f948DcE9C0deA, // CRV
            0x27665271210aCff4Fab08AD9Bb657E91866471F0, // FLOW
            0xC18f85A6DD3Bcd0516a1CA08d3B1f0A4E191A2C4, // FTM
            0xF9DD29D2Fd9B38Cd90E390C797F1B7E0523f43A9, // ADA
            0x69F5F465a46f324Fb7bf3fD7c0D5c00f7165C7Ea, // SHIB
            0x3D3f34416f60f77A0a6cC8e32abe45D32A7497cb, // PEPE
            0x09F9d7aaa6Bef9598c3b676c0E19C9786Aa566a8, // SUI
            0xa1Ace9ce6862e865937939005b1a6c5aC938A11F, // BLUR
            0x6110DF298B411a46d6edce72f5CAca9Ad826C1De, // XRP
            0x8B9B5f94aac2316f048025B3cBe442386E85984b, // DOT
            0x5ed8D0946b59d015f5A60039922b870537d43689, // FLOKI
            0x852210F0616aC226A486ad3387DBF990e690116A, // INJ
            0x031A448F59111000b96F016c37e9c71e57845096, // TRX
            0xD91Db82733987513286B81e7115091d96730b62A, // STETH
            0x4bF3C1Af0FaA689e3A808e6Ad7a8d89d07BB9EC7, // ETC
            0xb7059Ed9950f2D9fDc0155fC0D79e63d4441e806, // COMP
            0xf7d9Bd13F877171f6C7f93F71bdf8e380335dc12, // MKR
            0x2ea06E73083f1b3314Fa090eaE4a5F70eb058F2e, // XMR
            0x6940e7C6125a177b052C662189bb27692E88E9Cb, // YFI
            0x572F816F21F56D47e4c4fA577837bd3f58088676, // MAV
            0xfAD0835dAD2985b25ddab17eace356237589E5C7, // RPL
            0xD5FcCd43205CEF11FbaF9b38dF15ADbe1B186869, // ETHBTC
            0x77DA808032dCdd48077FA7c57afbF088713E09aD, // WLD
            0x1681212A0Edaf314496B489AB57cB3a5aD7a833f, // USDT
            0x50a40d947726ac1373DC438e7aaDEde9b237564d, // EOS
            0xEAf0191bCa9DD417202cEf2B18B7515ABff1E196, // RUNE
            0xfbbBFA96Af2980aE4014d5D5A2eF14bD79B2a299, // XLM
            0x96f2842007021a4C5f06Bcc72961701D66Ff8465, // ALGO
            0x2292865b2b6C837B7406E819200CE61c1c4F8d43, // CELO
            0x66fc48720f09Ac386608FB65ede53Bb220D0D5Bc, // SEI
            0xf8aB6B9008f2290965426d3076bC9d2EA835575e, // ZEC
            0x152Da6a8F32F25B56A32ef5559d4A2A96D09148b, // KNC
            0x01a43786C2279dC417e7901d45B917afa51ceb9a, // ZIL
            0xd5fAaa459e5B3c118fD85Fc0fD67f56310b1618D, // 1INCH
            0x105f7F2986A2414B4007958b836904100a53d1AD, // ICP
            0xC645A757DD81C69641e010aDD2Da894b4b7Bc921, // XTZ
            0xdcCDa0cFBEE25B33Ff4Ccca64467E89512511bf6, // SUSHI
            0x88C8316E5CCCCE2E27e5BFcDAC99f1251246196a, // ENJ
            0x86BbB4E38Ffa64F263E84A0820138c5d938BA86E, // ONE
            0x2fD9a39ACF071Aa61f92F3D7A98332c68d6B6602, // FXS
            0x71f42cA320b3e9A8e4816e26De70c9b69eAf9d24, // BAL
            0xaF2E4c337B038eaFA1dE23b44C163D0008e49EaD, // PERP
            0x91cc4a83d026e5171525aFCAEd020123A653c2C9, // RNDR
            0xb815Eb8D3a9dA3EdDD926225c0FBD3A566e8C749, // UMA
            0x76BB1Edf0C55eC68f4C8C7fb3C076b811b1a9b9f, // ZRX
            0x08388dC122A956887c2F736Aaec4A0Ce6f0536Ce // STETHETH
        ];

        bytes32[69] memory _ids = [
            bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace), // ETH
            bytes32(0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43), // BTC
            bytes32(0x3fa4252848f9f0a1480be62745a4629d9eb1322aebab8a791e344b3b9c1adcf5), // ARB
            bytes32(0x385f64d993f7b77d8182ed5003d97c60aa3361f3cecfe711544d2d59165e9bdf), // OP
            bytes32(0x93da3352f9f1d105fdfe4971cfa80e9dd777bfc5d0f683ebb6e1294b92137bb7), // AVAX
            bytes32(0x6489800bb8974169adfe35937bf6736507097d13c190d760c557108c7e93a81b), // DYDX
            bytes32(0x15add95022ae13563a11992e727c91bdb6b55bc183d9d747436c80a483d8c864), // APE
            bytes32(0x5de33a9112c2b700b8d30b8a3402c103578ccfa2765696471cc672bd5cf6ac52), // MATIC
            bytes32(0x2f95862b045670cd22bee3114c39763a4a08beeb663b145d283c31d7d1101c4f), // BNB
            bytes32(0xef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d), // SOL
            bytes32(0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221), // LINK
            bytes32(0xdcef50dd0a4cd2dcc17e45df1676dcb336a11a61c69df7a0299b0150c672d25c), // DOGE
            bytes32(0x2b9ab1e972a281585084148ba1389800799bd4be63b957507db1349314e47445), // AAVE
            bytes32(0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501), // UNI
            bytes32(0x3dd2b63686a450ec7290df3a1e0b583c0481f651351edfa7636f39aed55cf8a3), // BCH
            bytes32(0x6e3f3fa8253588df9326580180233eb791e03b443a3ba7a1d892e73874e19a54), // LTC
            bytes32(0xb962539d0fcb272a494d65ea56f94851c2bcf8823935da05bd628916e2e9edbf), // GMX
            bytes32(0xb00b60f88b03a6a625a8d1c048c3f66653edf217439983d037e7222c4e612819), // ATOM
            bytes32(0x03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5), // APT
            bytes32(0xb7e3904c08ddd9c0c10c6d207d390fd19e87eb6aab96304f571ed94caebdefa0), // AXS
            bytes32(0x150ac9b959aee0051e4091f0ef5216d941f590e1c5e7f91cf7635b5c11628c0e), // FIL
            bytes32(0xc63e2a7f37a04e5e614c07238bedb25dcc38927fba8fe890597a593c0b2fa4ad), // LDO
            bytes32(0xc415de8d2eba7db216527dff4b60e8f3a5311c740dadb233e13e12547e226750), // NEAR
            bytes32(0xa19d04ac696c7a6616d291c7e5d1377cc8be437c327b75adb5dc1bad745fcae8), // CRV
            bytes32(0x2fb245b9a84554a0f15aa123cbb5f64cd263b59e9a87d80148cbffab50c69f30), // FLOW
            bytes32(0x5c6c0d2386e3352356c3ab84434fafb5ea067ac2678a38a338c4a69ddc4bdb0c), // FTM
            bytes32(0x2a01deaec9e51a579277b34b122399984d0bbf57e2458a7e42fecd2829867a0d), // ADA
            bytes32(0xf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a), // SHIB
            bytes32(0xd69731a2e74ac1ce884fc3890f7ee324b6deb66147055249568869ed700882e4), // PEPE
            bytes32(0x23d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc65744), // SUI
            bytes32(0x856aac602516addee497edf6f50d39e8c95ae5fb0da1ed434a8c2ab9c3e877e9), // BLUR
            bytes32(0xec5d399846a9209f3fe5881d70aae9268c94339ff9817e8d18ff19fa05eea1c8), // XRP
            bytes32(0xca3eed9b267293f6595901c734c7525ce8ef49adafe8284606ceb307afa2ca5b), // DOT
            bytes32(0x6b1381ce7e874dc5410b197ac8348162c0dd6c0d4c9cd6322672d6c2b1d58293), // FLOKI
            bytes32(0x7a5bc1d2b56ad029048cd63964b3ad2776eadf812edc1a43a31406cb54bff592), // INJ
            bytes32(0x67aed5a24fdad045475e7195c98a98aea119c763f272d4523f5bac93a4f33c2b), // TRX
            bytes32(0x846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b5), // STETH
            bytes32(0x7f5cc8d963fc5b3d2ae41fe5685ada89fd4f14b435f8050f28c7fd409f40c2d8), // ETC
            bytes32(0x4a8e42861cabc5ecb50996f92e7cfa2bce3fd0a2423b0c44c9b423fb2bd25478), // COMP
            bytes32(0x9375299e31c0deb9c6bc378e6329aab44cb48ec655552a70d4b9050346a30378), // MKR
            bytes32(0x46b8cc9347f04391764a0361e0b17c3ba394b001e7c304f7650f6376e37c321d), // XMR
            bytes32(0x425f4b198ab2504936886c1e93511bb6720fbcf2045a4f3c0723bb213846022f), // YFI
            bytes32(0x5b131ede5d017511cf5280b9ebf20708af299266a033752b64180c4201363b11), // MAV
            bytes32(0x24f94ac0fd8638e3fc41aab2e4df933e63f763351b640bf336a6ec70651c4503), // RPL
            bytes32(0xc96458d393fe9deb7a7d63a0ac41e2898a67a7750dbd166673279e06c868df0a), // ETHBTC
            bytes32(0xd6835ad1f773de4a378115eb6824bd0c0e42d84d1c84d9750e853fb6b6c7794a), // WLD
            bytes32(0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b), // USDT
            bytes32(0x06ade621dbc31ed0fc9255caaab984a468abe84164fb2ccc76f02a4636d97e31), // EOS
            bytes32(0x5fcf71143bb70d41af4fa9aa1287e2efd3c5911cee59f909f915c9f61baacb1e), // RUNE
            bytes32(0xb7a8eba68a997cd0210c2e1e4ee811ad2d174b3611c22d9ebf16f4cb7e9ba850), // XLM
            bytes32(0xfa17ceaf30d19ba51112fdcc750cc83454776f47fb0112e4af07f15f4bb1ebc0), // ALGO
            bytes32(0x7d669ddcdd23d9ef1fa9a9cc022ba055ec900e91c4cb960f3c20429d4447a411), // CELO
            bytes32(0x53614f1cb0c031d4af66c04cb9c756234adad0e1cee85303795091499a4084eb), // SEI
            bytes32(0xbe9b59d178f0d6a97ab4c343bff2aa69caa1eaae3e9048a65788c529b125bb24), // ZEC
            bytes32(0xb9ccc817bfeded3926af791f09f76c5ffbc9b789cac6e9699ec333a79cacbe2a), // KNC
            bytes32(0x609722f3b6dc10fee07907fe86781d55eb9121cd0705b480954c00695d78f0cb), // ZIL
            bytes32(0x63f341689d98a12ef60a5cff1d7f85c70a9e17bf1575f0e7c0b2512d48b1c8b3), // 1INCH
            bytes32(0xc9907d786c5821547777780a1e4f89484f3417cb14dd244f2b0a34ea7a554d67), // ICP
            bytes32(0x0affd4b8ad136a21d79bc82450a325ee12ff55a235abc242666e423b8bcffd03), // XTZ
            bytes32(0x26e4f737fde0263a9eea10ae63ac36dcedab2aaf629261a994e1eeb6ee0afe53), // SUSHI
            bytes32(0x5cc254b7cb9532df39952aee2a6d5497b42ec2d2330c7b76147f695138dbd9f3), // ENJ
            bytes32(0xc572690504b42b57a3f7aed6bd4aae08cbeeebdadcf130646a692fe73ec1e009), // ONE
            bytes32(0x735f591e4fed988cd38df74d8fcedecf2fe8d9111664e0fd500db9aa78b316b1), // FXS
            bytes32(0x07ad7b4a7662d19a6bc675f6b467172d2f3947fa653ca97555a9b20236406628), // BAL
            bytes32(0x944f2f908c5166e0732ea5b610599116cd8e1c41f47452697c1e84138b7184d6), // PERP
            bytes32(0xab7347771135fc733f8f38db462ba085ed3309955f42554a14fa13e855ac0e2f), // RNDR
            bytes32(0x4b78d251770732f6304b1f41e9bebaabc3b256985ef18988f6de8d6562dd254c), // UMA
            bytes32(0x7d17b9fe4ea7103be16b6836984fabbc889386d700ca5e5b3d34b7f92e449268), // ZRX
            bytes32(0x3af6a3098c56f58ff47cc46dee4a5b1910e5c157f7f0b665952445867470d61f) // STETHETH
        ];

        for (uint256 i = 0; i < 69; i++) {
            markets[i] = _markets[i];
            ids[i] = _ids[i];
        }

        target.updatePythOracleIds(markets, ids);

        vm.stopBroadcast();
    }
}
