// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {wadDiv} from "solmate/utils/SignedWadMath.sol";

import {console2} from "forge-std/console2.sol";

interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);
}

interface IExchanger {
    function dynamicFeeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint256 feeRate, bool tooVolatile);
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
    function baseAsset() external view returns (bytes32 key);
    function assetPrice() external view returns (uint256 price, bool invalid);
    function marketSkew() external view returns (int256 skew);
    function marketSize() external view returns (uint256 size);
    function marketKey() external view returns (bytes32 key);
    function remainingMargin(address account) external view returns (uint256 marginRemaining, bool invalid);
    function orderFee(int256 sizeDelta, uint8 orderType) external view returns (uint256 fee, bool invalid);
    function fundingLastRecomputed() external view returns (uint32 timestamp);
    function fundingSequence(uint256 index) external view returns (int128 netFunding);
    function currentFundingRate() external view returns (int256 fundingRate);
    function currentFundingVelocity() external view returns (int256 fundingVelocity);
    function unrecordedFunding() external view returns (int256 funding, bool invalid);
    function fundingSequenceLength() external view returns (uint256 length);
}

contract SynthetixPerpResolver {
    using FixedPointMathLib for uint256;

    struct Data {
        bool isMaxMarket;
        bool tooVolatile;
        bytes32 marketKey;
        uint256 currentPrice;
        uint256 margin;
        uint256 minMargin;
    }

    enum Status {
        Ok,
        InvalidPrice,
        InvalidOrderPrice,
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

    IAddressResolver private constant addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);

    IFuturesMarketManager private constant marketManager =
        IFuturesMarketManager(0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e);

    function calculate(address market, int256 marginDelta, int256 sizeDelta, address account)
        external
        view
        returns (
            uint256 fee,
            uint256 liquidationPrice,
            uint256 totalMargin,
            uint256 accessibleMargin,
            uint256 assetPrice,
            Status status
        )
    {
        IPerpMarket perpMarket = IPerpMarket(market);
        IPerpMarket.Position memory position = perpMarket.positions(account);
        console2.log("yay", position.margin);
        Data memory data;

        data.marketKey = perpMarket.marketKey();

        IExchanger exchanger = IExchanger(addressResolver.getAddress("Exchanger"));
        (, data.tooVolatile) = exchanger.dynamicFeeRateForExchange("sUSD", perpMarket.baseAsset());

        if (data.tooVolatile) {
            status = Status.PriceTooVolatile;
        }

        (data.currentPrice,) = perpMarket.assetPrice();

        (fee,) = perpMarket.orderFee(sizeDelta, 2);

        (data.margin,) = perpMarket.remainingMargin(account);

        if (sizeDelta > 0) {
            data.margin += _abs(marginDelta);
        } else {
            uint256 absMargin = _abs(marginDelta);
            if (absMargin > data.margin) {
                status = Status.InsufficientMargin;
            }
            data.margin -= _abs(marginDelta);
        }

        data.margin -= fee + 2e18;

        data.minMargin = _getParam(data.marketKey, "perpsV2MinInitialMargin");

        if (data.margin < data.minMargin) {
            status = Status.InsufficientMargin;
        }

        int256 oldSize = position.size;

        position.size += int128(sizeDelta);

        data.isMaxMarket = _isMaxMarket(perpMarket, oldSize, position.size);

        if (data.isMaxMarket) {
            status = Status.MaxMarketSizeExceeded;
        }

        int256 liquidationMargin = int256(_liquidationMargin(data.marketKey, position.size, data.currentPrice));

        if (_abs(liquidationMargin) >= data.margin) {
            status = Status.CanLiquidate;
        }

        int256 liquidationPremium = int256(_liquidationPremium(data.marketKey, position.size, data.currentPrice));
        int256 liqPrice = position.size == 0
            ? int256(0)
            : (
                int256(data.currentPrice)
                    + wadDiv(liquidationMargin - int256(data.margin) - liquidationPremium, position.size)
            );
        liquidationPrice = uint256(_max(0, liqPrice));

        uint256 leverage = data.margin == 0 ? 0 : _abs(int256(position.size)).mulDivDown(data.currentPrice, data.margin);
        uint256 maxLeverage = _getParam(data.marketKey, "maxLeverage") + 1e16;

        if (leverage > maxLeverage) {
            status = Status.MaxLeverageExceeded;
        }

        totalMargin = data.margin;

        uint256 inaccessible = _inaccessibleMargin(data.marketKey, position.size, data.currentPrice, data.minMargin);
        if (inaccessible < totalMargin) {
            accessibleMargin = totalMargin - inaccessible;
        }
        assetPrice = data.currentPrice;
    }

    function _liquidationMargin(bytes32 marketKey, int256 size, uint256 price) internal view returns (uint256) {
        uint256 liquidationBufferParam = _getParam(marketKey, "perpsV2LiquidationBufferRatio");
        uint256 liquidationBuffer = _abs(size).mulWadDown(price).mulWadDown(liquidationBufferParam);
        uint256 liquidationFeeRatio = _getParam(marketKey, "perpsV2LiquidationFeeRatio");
        uint256 proportionalFee = _abs(size).mulWadDown(price).mulWadDown(liquidationFeeRatio);
        uint256 maxKeeperFee = _getParam(marketKey, "perpsV2MaxKeeperFee");
        uint256 cappedProportionalFee = proportionalFee > maxKeeperFee ? maxKeeperFee : proportionalFee;
        uint256 minKeeperFee = _getParam(marketKey, "perpsV2MinKeeperFee");
        uint256 liquidationFee = cappedProportionalFee > minKeeperFee ? cappedProportionalFee : minKeeperFee;

        return liquidationBuffer + liquidationFee;
    }

    function _liquidationPremium(bytes32 marketKey, int256 size, uint256 price) internal view returns (uint256) {
        if (size == 0) {
            return 0;
        }
        uint256 notionalSize = _abs(size).mulWadDown(price);
        uint256 skewScale = _getParam(marketKey, "skewScale");
        uint256 liquidationPremiumMultiplier = _getParam(marketKey, "liquidationPremiumMultiplier");
        return _abs(size).divWadDown(skewScale).mulWadDown(notionalSize).mulWadDown(liquidationPremiumMultiplier);
    }

    function _isMaxMarket(IPerpMarket perpMarket, int256 oldSize, int256 newSize) internal view returns (bool) {
        if (_sameSide(oldSize, newSize) && _abs(newSize) <= _abs(oldSize)) {
            return false;
        }
        bytes32 marketKey = perpMarket.marketKey();
        uint256 maxMarketSize = _getParam(marketKey, "maxMarketValue");
        int256 skew = perpMarket.marketSkew() - oldSize + newSize;
        int256 marketSize = int256(perpMarket.marketSize()) - int256(_abs(oldSize)) + int256(_abs(newSize));
        int256 sideSize;

        if (newSize > 0) {
            sideSize = marketSize + skew;
        } else {
            sideSize = marketSize - skew;
        }

        if (maxMarketSize < _abs(sideSize / 2)) {
            return true;
        }

        return false;
    }

    function _inaccessibleMargin(bytes32 marketKey, int256 size, uint256 price, uint256 minMargin)
        internal
        view
        returns (uint256)
    {
        uint256 maxLeverage = _getParam(marketKey, "maxLeverage") - 1e15;
        uint256 notionalSize = _abs(size).mulWadDown(price);
        uint256 inaccessible = notionalSize.divWadDown(maxLeverage);

        if (inaccessible > 0) {
            if (minMargin > inaccessible) {
                inaccessible = minMargin;
            }
            inaccessible += 1e15;
        }

        return inaccessible;
    }

    function _getParam(bytes32 marketKey, bytes32 value) internal view returns (uint256) {
        IFlexibleStorage flexibleStorage = IFlexibleStorage(addressResolver.getAddress("FlexibleStorage"));

        return flexibleStorage.getUIntValue("PerpsV2MarketSettings", keccak256(abi.encodePacked(marketKey, value)));
    }

    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }

    function _max(int256 x, int256 y) internal pure returns (int256) {
        return x < y ? y : x;
    }

    function _sameSide(int256 a, int256 b) internal pure returns (bool) {
        return (a == 0) || (b == 0) || (a > 0) == (b > 0);
    }
}
