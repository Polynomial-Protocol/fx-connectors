// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {wadDiv} from "solmate/utils/SignedWadMath.sol";

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

    IAddressResolver private constant addressResolver = IAddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);

    IFuturesMarketManager private constant marketManager =
        IFuturesMarketManager(0xdb89f3fc45A707Dd49781495f77f8ae69bF5cA6e);

    function calculate(address market, int256 marginDelta, int256 sizeDelta, address account)
        external
        view
        returns (uint256)
    {
        IPerpMarket perpMarket = IPerpMarket(market);
        IPerpMarket.Position memory position = perpMarket.positions(account);
        bytes32 marketKey = perpMarket.marketKey();

        (uint256 price,) = perpMarket.assetPrice();

        (uint256 fee,) = perpMarket.orderFee(sizeDelta, 2);

        (uint256 margin,) = perpMarket.remainingMargin(account);

        if (sizeDelta > 0) {
            margin += _abs(marginDelta);
        } else {
            uint256 absMargin = _abs(marginDelta);
            if (absMargin > margin) {
                // Insufficient Margin
            }
            margin -= _abs(marginDelta);
        }

        position.size += int128(sizeDelta);
        margin -= fee + 2e18;

        int256 liquidationMargin = int256(_liquidationMargin(marketKey, position.size, price));
        int256 liquidationPremium = int256(_liquidationPremium(marketKey, position.size, price));
        int256 liquidationPrice =
            int256(price) + wadDiv(liquidationMargin - int256(margin) - liquidationPremium, position.size);
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
        uint256 notionalSize = _abs(size).mulWadDown(price);
        uint256 skewScale = _getParam(marketKey, "skewScale");
        uint256 liquidationPremiumMultiplier = _getParam(marketKey, "liquidationPremiumMultiplier");
        return _abs(size).divWadDown(skewScale).mulWadDown(notionalSize).mulWadDown(liquidationPremiumMultiplier);
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
}
