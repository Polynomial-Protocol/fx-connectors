// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {wadMul, wadDiv} from "solmate/utils/SignedWadMath.sol";

interface IPerpMarket {
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    function marketKey() external view returns (bytes32 key);

    function assetPrice() external view returns (uint256 price, bool invalid);

    function fillPrice(int256 sizeDelta) external view returns (uint256 price, bool invalid);

    function positions(address account) external view returns (Position memory);

    function canLiquidate(address account) external view returns (bool);

    function accruedFunding(address account) external view returns (int256 funding, bool invalid);

    function profitLoss(address account) external view returns (int256 pnl, bool invalid);

    function orderFee(int256 sizeDelta, uint8 orderType) external view returns (uint256 fee, bool invalid);

    function marketSize() external view returns (uint128 size);

    function marketSkew() external view returns (int128 skew);

    function fundingSequenceLength() external view returns (uint256 length);

    function unrecordedFunding() external view returns (int256 funding, bool invalid);

    function fundingSequence(uint256 index) external view returns (int128 netFunding);
}

interface IPerpMarketSettings {
    function takerFeeOffchainDelayedOrder(bytes32 _marketKey) external view returns (uint256);

    function makerFeeOffchainDelayedOrder(bytes32 _marketKey) external view returns (uint256);

    function minKeeperFee() external view returns (uint256);

    function maxKeeperFee() external view returns (uint256);

    function liquidationFeeRatio() external view returns (uint256);
}

interface IFlexibleStorage {
    function getUIntValue(bytes32 contractName, bytes32 record) external view returns (uint256);
}

interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

contract Boomerang {
    using FixedPointMathLib for uint256;

    struct TradeParams {
        int256 marginDelta;
        int256 sizeDelta;
        uint256 oraclePrice;
        uint256 fillPrice;
        uint256 desiredFillPrice;
    }

    struct DataHolder {
        uint256 fee;
        uint256 keeperFee;
        int256 slot0;
        int256 slot1;
        int256 slot2;
        uint256 lMargin;
        uint256 maxMarketValue;
        uint256 latestFundingIndex;
    }

    struct PostTradeInput {
        IPerpMarket market;
        bytes32 marketKey;
    }

    enum Status {
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
        PriceImpactToleranceExceeded,
        PositionFlagged,
        PositionNotFlagged
    }

    IAddressResolver private constant addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);

    IPerpMarketSettings settings;

    constructor(address settings_) {
        settings = IPerpMarketSettings(settings_);
    }

    function calculate(address market_, int256 sizeDelta, int256 marginDelta, address sender)
        external
        view
        returns (uint256 margin, int256 size, uint256 price, uint256 liqPrice, uint256 fee, Status status)
    {
        PostTradeInput memory postTradeInput;
        postTradeInput.market = IPerpMarket(market_);
        postTradeInput.marketKey = postTradeInput.market.marketKey();
        TradeParams memory params;

        params.marginDelta = marginDelta;
        params.sizeDelta = sizeDelta;

        (params.oraclePrice,) = postTradeInput.market.assetPrice();
        (params.fillPrice,) = postTradeInput.market.fillPrice(sizeDelta);

        params.desiredFillPrice = params.oraclePrice;

        (IPerpMarket.Position memory newPosition, uint256 fee_, Status status_) =
            _postTradeDetails(postTradeInput.marketKey, params, postTradeInput.market, sender);

        liqPrice = _approxLiquidationPrice(newPosition, postTradeInput.market, newPosition.lastPrice);

        return (newPosition.margin, newPosition.size, newPosition.lastPrice, liqPrice, fee_, status_);
    }

    function _postTradeDetails(bytes32 marketKey, TradeParams memory params, IPerpMarket market, address sender)
        internal
        view
        returns (IPerpMarket.Position memory newPosition, uint256 fee, Status tradeStatus)
    {
        IPerpMarket.Position memory oldPos = market.positions(sender);
        DataHolder memory data;

        if (params.sizeDelta == 0) {
            return (oldPos, 0, Status.NilOrder);
        }

        if (market.canLiquidate(sender)) {
            return (oldPos, 0, Status.CanLiquidate);
        }

        (data.fee,) = market.orderFee(params.sizeDelta, 2);
        data.keeperFee = settings.minKeeperFee();

        (data.slot0,) = market.accruedFunding(sender);
        (data.slot1,) = market.profitLoss(sender);

        uint256 uMargin = uint256(oldPos.margin);

        // newMargin
        data.slot2 = int256(uMargin) + data.slot0 + data.slot1 - int256(data.fee + data.keeperFee);

        uMargin = uint256(data.slot2);

        if (data.slot2 < 0) {
            return (oldPos, 0, Status.InsufficientMargin);
        }

        data.slot0 = int256(oldPos.size);

        data.lMargin = _liquidationMargin(marketKey, data.slot0, params.oraclePrice);

        if (data.slot0 != 0 && uMargin <= data.lMargin) {
            return (oldPos, uMargin, Status.CanLiquidate);
        }

        data.slot1 = oldPos.size + params.sizeDelta;

        data.latestFundingIndex = market.fundingSequenceLength() - 1;

        IPerpMarket.Position memory newPos = IPerpMarket.Position({
            id: oldPos.id,
            lastFundingIndex: uint64(data.latestFundingIndex),
            margin: uint128(uMargin),
            lastPrice: uint128(params.fillPrice),
            size: int128(data.slot1)
        });

        bool positionDecreasing = _sameSide(oldPos.size, newPos.size) && _abs(newPos.size) < _abs(oldPos.size);

        if (!positionDecreasing) {
            // minMargin + fee <= margin is equivalent to minMargin <= margin - fee
            // except that we get a nicer error message if fee > margin, rather than arithmetic overflow.
            if (uint256(newPos.margin) + data.fee < _minInitialMargin()) {
                return (oldPos, 0, Status.InsufficientMargin);
            }
        }

        uint256 liqPremium = _liquidationPremium(marketKey, newPos.size, params.oraclePrice);
        data.lMargin = _liquidationMargin(marketKey, newPos.size, params.oraclePrice) + liqPremium;
        if (uMargin <= data.lMargin) {
            return (newPos, 0, Status.CanLiquidate);
        }

        uint256 leverage = _abs(newPos.size).mulDivDown(params.fillPrice, uMargin + data.fee + data.keeperFee);
        uint256 maxLeverage = _getParam(marketKey, "maxLeverage");

        if (maxLeverage + 1e16 < leverage) {
            return (oldPos, 0, Status.MaxLeverageExceeded);
        }

        data.maxMarketValue = _getParam(marketKey, "maxMarketValue");

        if (_orderSizeTooLarge(market, data.maxMarketValue, oldPos.size, newPos.size)) {
            return (oldPos, 0, Status.MaxMarketSizeExceeded);
        }

        return (newPos, data.fee, Status.Ok);
    }

    function _liquidationFee(int256 positionSize, uint256 price) internal view returns (uint256 lFee) {
        // uint proportionalFee = _abs(positionSize).multiplyDecimal(price).multiplyDecimal(_liquidationFeeRatio());

        uint256 liqFeeRatio = settings.liquidationFeeRatio();
        uint256 proportionalFee = _abs(positionSize).mulWadDown(price).mulWadDown(liqFeeRatio);
        uint256 maxFee = settings.maxKeeperFee();
        uint256 cappedProportionalFee = proportionalFee > maxFee ? maxFee : proportionalFee;
        uint256 minFee = settings.minKeeperFee();

        return cappedProportionalFee > minFee ? cappedProportionalFee : minFee;
    }

    function _keeperLiquidationFee() internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", "keeperLiquidationFee");
    }

    function _liquidationMargin(bytes32 marketKey, int256 positionSize, uint256 price)
        internal
        view
        returns (uint256 lMargin)
    {
        // uint liquidationBuffer =
        //     _abs(positionSize).multiplyDecimal(price).multiplyDecimal(_liquidationBufferRatio(_marketKey()));

        uint256 liquidationBufferRatio = _getParam(marketKey, "liquidationBufferRatio");
        uint256 liquidationBuffer = _abs(positionSize).mulWadDown(price).mulWadDown(liquidationBufferRatio);

        return liquidationBuffer + _liquidationFee(positionSize, price) + _keeperLiquidationFee();
    }

    function _getParam(bytes32 marketKey, bytes32 value) internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", keccak256(abi.encodePacked(marketKey, value)));
    }

    function _minInitialMargin() internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", "perpsV2MinInitialMargin");
    }

    function _notionalValue(int256 positionSize, uint256 price) internal pure returns (int256 value) {
        return wadMul(positionSize, int256(price));
    }

    function _liquidationPremium(bytes32 marketKey, int256 positionSize, uint256 currentPrice)
        internal
        view
        returns (uint256)
    {
        if (positionSize == 0) {
            return 0;
        }

        uint256 notional = _abs(_notionalValue(positionSize, currentPrice));
        uint256 skewScale = _getParam(marketKey, "skewScale");
        uint256 liquidationPremiumMultiplier = _getParam(marketKey, "liquidationPremiumMultiplier");

        return _abs(positionSize).mulWadDown(notional).mulDivDown(liquidationPremiumMultiplier, skewScale);
    }

    function _orderSizeTooLarge(IPerpMarket market, uint256 maxSize, int256 oldSize, int256 newSize)
        internal
        view
        returns (bool)
    {
        // Allow users to reduce an order no matter the market conditions.
        if (_sameSide(oldSize, newSize) && _abs(newSize) <= _abs(oldSize)) {
            return false;
        }

        int256 marketSkew = market.marketSkew();
        uint256 marketSize = market.marketSize();

        int256 newSkew = marketSkew - oldSize + newSize;
        int256 newMarketSize = int256(marketSize) - (_signedAbs(oldSize)) + (_signedAbs(newSize));

        int256 newSideSize;
        if (0 < newSize) {
            // long case: marketSize + skew
            //            = (|longSize| + |shortSize|) + (longSize + shortSize)
            //            = 2 * longSize
            newSideSize = newMarketSize + (newSkew);
        } else {
            // short case: marketSize - skew
            //            = (|longSize| + |shortSize|) - (longSize + shortSize)
            //            = 2 * -shortSize
            newSideSize = newMarketSize - (newSkew);
        }

        // newSideSize still includes an extra factor of 2 here, so we will divide by 2 in the actual condition
        if (maxSize < _abs(newSideSize / 2)) {
            return true;
        }

        return false;
    }

    function _approxLiquidationPrice(IPerpMarket.Position memory position, IPerpMarket market, uint256 currentPrice)
        internal
        view
        returns (uint256)
    {
        if (position.size == 0) {
            return 0;
        }

        uint256 liqMargin = _liquidationMargin(market.marketKey(), position.size, currentPrice);
        uint256 liqPremium = _liquidationPremium(market.marketKey(), position.size, currentPrice);

        int256 midValue = int256(liqMargin) - int128(position.margin) - int256(liqPremium);
        midValue = wadDiv(midValue, position.size);

        int256 netFundingPerUnit = _netFundingPerUnit(market, position.lastFundingIndex);

        int256 result = int256(uint256(position.lastPrice)) + midValue - netFundingPerUnit;

        return uint256(_max(0, result));
    }

    function _nextFundingEntry(IPerpMarket market) internal view returns (int256) {
        (int256 unrecordedFunding,) = market.unrecordedFunding();
        uint256 latestFundingIndex = market.fundingSequenceLength() - 1;
        return market.fundingSequence(latestFundingIndex) + unrecordedFunding;
    }

    function _netFundingPerUnit(IPerpMarket market, uint256 startIndex) internal view returns (int256) {
        // Compute the net difference between start and end indices.
        return _nextFundingEntry(market) - market.fundingSequence(startIndex);
    }

    /*
     * Absolute value of the input, returned as a signed number.
     */
    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    /*
     * Absolute value of the input, returned as an unsigned number.
     */
    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }

    function _max(int256 x, int256 y) internal pure returns (int256) {
        return x < y ? y : x;
    }

    function _min(int256 x, int256 y) internal pure returns (int256) {
        return x < y ? x : y;
    }

    /*
     * True if and only if two positions a and b are on the same side of the market; that is, if they have the same
     * sign, or either of them is zero.
     */
    function _sameSide(int256 a, int256 b) internal pure returns (bool) {
        return (a == 0) || (b == 0) || (a > 0) == (b > 0);
    }
}
