// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Auth, Authority} from "solmate/auth/Auth.sol";

interface IPerpsV2MarketSettings {
    function skewScale(bytes32 _marketKey) external view returns (uint256);

    function liquidationPremiumMultiplier(bytes32 _marketKey) external view returns (uint256);

    function liquidationBufferRatio(bytes32 _marketKey) external view returns (uint256);

    function minKeeperFee() external view returns (uint256);

    function maxKeeperFee() external view returns (uint256);

    function liquidationFeeRatio() external view returns (uint256);

    function keeperLiquidationFee() external view returns (uint256);
}

interface IPerpV2Market {
    function assetPrice() external view returns (uint256 price, bool invalid);

    function marketKey() external view returns (bytes32 key);
}

contract BellPepper is Auth {
    struct Params {
        uint256 assetPrice;
        uint256 skewScale;
        uint256 liquidationPremiumMultiplier;
        uint256 liquidationBufferRatio;
        uint256 minKeeperFee;
        uint256 maxKeeperFee;
        uint256 liquidationFeeRatio;
        uint256 keeperLiquidationFee;
    }

    IPerpsV2MarketSettings settings;

    constructor(address _settings) Auth(msg.sender, Authority(address(0x0))) {
        settings = IPerpsV2MarketSettings(_settings);
    }

    function setSettings(address _settings) external requiresAuth {
        settings = IPerpsV2MarketSettings(_settings);
    }

    function getMarketParams(address market) public view returns (Params memory params) {
        IPerpV2Market perpMarket = IPerpV2Market(market);

        (params.assetPrice,) = perpMarket.assetPrice();
        bytes32 marketKey = perpMarket.marketKey();

        params.skewScale = settings.skewScale(marketKey);
        params.liquidationPremiumMultiplier = settings.liquidationPremiumMultiplier(marketKey);
        params.liquidationBufferRatio = settings.liquidationBufferRatio(marketKey);
        params.minKeeperFee = settings.minKeeperFee();
        params.maxKeeperFee = settings.maxKeeperFee();
        params.liquidationFeeRatio = settings.liquidationFeeRatio();
        params.keeperLiquidationFee = settings.keeperLiquidationFee();
    }
}
