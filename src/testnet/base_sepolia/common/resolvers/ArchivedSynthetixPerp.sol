// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {wadDiv, wadMul} from "solmate/utils/SignedWadMath.sol";

interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

interface IFlexibleStorage {
    function getUIntValue(bytes32 contractName, bytes32 record) external view returns (uint256);
}

interface IFuturesMarketManager {
    function marketForKey(bytes32 marketKey) external view returns (address);
}

interface IPerpMarket {
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    function positions(address account) external view returns (Position memory);
    function assetPrice() external view returns (uint256 price, bool invalid);
    function marketSkew() external view returns (int128 skew);
    function marketKey() external view returns (bytes32 key);
}

contract ArchivedSynthetixPerpResolver {
    enum TradeStatus {
        Ok,
        InvalidPrice,
        InvalidOrderType,
        PriceOutOfBounds,
        CanLiquidate,
        CannotLiquidate,
        MaxMarketSizeExceeded,
        MaxLeverageExceeded,
        InsufficientMargin,
        NotPermitted,
        NilOrder,
        NoPositionOpen,
        PriceTooVolatile,
        PriceImpactToleranceExceeded
    }

    struct TradeParams {
        int256 sizeDelta;
        uint256 oraclePrice;
        uint256 fillPrice;
        uint256 takerFee;
        uint256 makerFee;
        uint256 priceImpactDelta;
    }

    IAddressResolver private constant addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);

    IFuturesMarketManager private constant marketManager =
        IFuturesMarketManager(0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e);

    function postTradeDetails(bytes32 marketKey, int256 sizeDelta, address sender)
        external
        view
        returns (uint256 margin, int256 size, uint256 price, uint256 liqPrice, uint256 fee, TradeStatus status)
    {
        TradeParams memory params;
        uint256 tradePrice;
        IPerpMarket perpMarket = IPerpMarket(marketManager.marketForKey(marketKey));

        {
            bool isInvalid;

            params.makerFee = _getParam(marketKey, "makerFeeOffchainDelayedOrder");
            params.takerFee = _getParam(marketKey, "takerFeeOffchainDelayedOrder");

            (params.oraclePrice, isInvalid) = perpMarket.assetPrice();

            if (isInvalid) {
                return (0, 0, 0, 0, 0, TradeStatus.InvalidPrice);
            }
        }

        IPerpMarket.Position memory position = perpMarket.positions(sender);

        params.fillPrice = _fillPrice(perpMarket, sizeDelta, tradePrice);
        params.sizeDelta = sizeDelta;
    }

    function _getParam(bytes32 marketKey, bytes32 value) internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", keccak256(abi.encodePacked(marketKey, value)));
    }

    function _fillPrice(IPerpMarket perpMarket, int256 size, uint256 price) internal view returns (uint256) {
        int256 skew = perpMarket.marketSkew();
        int256 skewScale = int256(_getParam(perpMarket.marketKey(), "skewScale"));
        int256 pdBefore = wadDiv(skew, skewScale);
        int256 pdAfter = wadDiv(skew + size, skewScale);
        int256 priceInt = int256(price);
        int256 priceBefore = wadMul(2 * priceInt, pdBefore);
        int256 priceAfter = wadMul(2 * priceInt, pdAfter);
        return uint256(wadDiv(priceBefore + priceAfter, 2e18));
    }
}
