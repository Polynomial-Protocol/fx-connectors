// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

interface IMarketData {
    struct FeeRates {
        uint256 takerFee;
        uint256 makerFee;
        uint256 takerFeeDelayedOrder;
        uint256 makerFeeDelayedOrder;
        uint256 takerFeeOffchainDelayedOrder;
        uint256 makerFeeOffchainDelayedOrder;
    }

    struct MarketSummary {
        address market;
        bytes32 asset;
        bytes32 key;
        uint256 maxLeverage;
        uint256 price;
        uint256 marketSize;
        int256 marketSkew;
        uint256 marketDebt;
        int256 currentFundingRate;
        int256 currentFundingVelocity;
        FeeRates feeRates;
    }

    function marketSummariesForKeys(bytes32[] calldata markets) external view returns (MarketSummary[] memory);
}

interface IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external;
    function isAuth(address user) external view returns (bool);
}

interface IAccountResolver {
    function getAuthorityAccounts(address authority) external view returns (address[] memory);
}

contract CloseAll is ReentrancyGuard {
    IAccountResolver public immutable resolver;
    IMarketData public immutable marketData;

    constructor(address _resolver, address _marketData) {
        resolver = IAccountResolver(_resolver);
        marketData = IMarketData(_marketData);
    }

    function closeAll(address[] memory markets) external nonReentrant {
        address[] memory scws = resolver.getAuthorityAccounts(msg.sender);

        for (uint32 i = 0; i < scws.length; i++) {
            _closeAll(scws[i], markets);
        }
    }

    function closeAll(bytes32[] memory marketKeys) external nonReentrant {
        address[] memory scws = resolver.getAuthorityAccounts(msg.sender);

        IMarketData.MarketSummary[] memory datas = marketData.marketSummariesForKeys(marketKeys);
        address[] memory markets = new address[](datas.length);

        for (uint32 i = 0; i < datas.length; i++) {
            markets[i] = datas[i].market;
        }

        for (uint32 i = 0; i < scws.length; i++) {
            _closeAll(scws[i], markets);
        }
    }

    function close(address market) external nonReentrant {
        address[] memory scws = resolver.getAuthorityAccounts(msg.sender);

        address[] memory markets = new address[](1);
        markets[0] = market;

        for (uint32 i = 0; i < scws.length; i++) {
            _closeAll(scws[i], markets);
        }
    }

    function close(string memory marketName) external nonReentrant {
        address[] memory scws = resolver.getAuthorityAccounts(msg.sender);

        bytes32 marketKey = bytes32(abi.encodePacked(marketName));
        bytes32[] memory marketKeys = new bytes32[](1);
        marketKeys[0] = marketKey;

        IMarketData.MarketSummary[] memory datas = marketData.marketSummariesForKeys(marketKeys);
        address[] memory markets = new address[](1);
        markets[0] = datas[0].market;

        for (uint32 i = 0; i < scws.length; i++) {
            _closeAll(scws[i], markets);
        }
    }

    function _closeAll(address scw, address[] memory markets) internal {
        IAccount account = IAccount(scw);

        uint256 count = markets.length;

        string[] memory targetNames = new string[](count);
        bytes[] memory datas = new bytes[](count);

        for (uint32 i = 0; i < count; i++) {
            targetNames[i] = "Synthetix-Perp-v1.3";
            datas[i] = abi.encodeWithSignature("closeTrade(address,uint256)", markets[i], 1e16);
        }

        account.cast(targetNames, datas, address(this));
    }
}
