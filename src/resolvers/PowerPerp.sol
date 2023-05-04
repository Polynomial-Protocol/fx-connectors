// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {wadDiv} from "solmate/utils/SignedWadMath.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";


struct ShortPosition {
    uint256 positionId;
    uint256 shortAmount;
    uint256 collateralAmount;
    address collateral;
}

struct Collateral {
    bytes32 currencyKey;
    address synth;
    bool isApproved;
    uint256 collateralRatio;
    uint256 liqRatio;
    uint256 liqBonus;
}

interface ILiquidityPool {
    function getSlippageFee(uint256) external view returns (uint256);
    function baseTradingFee() external view returns (uint256);
    function getMarkPrice() external view returns (uint256);
    function orderFee(int256) external view returns (uint256);
}

interface IShortCollateral {
    function collaterals(bytes32) external view returns (Collateral memory);
}

interface IShortToken {
    function shortPositions(uint256 positionId) external view returns (ShortPosition memory);
    function totalSupply() external view returns (uint256);
}

interface ISystemManager {
    function pool() external view returns (ILiquidityPool);

    function shortCollateral() external view returns (IShortCollateral);

    function shortToken() external view returns (IShortToken);

    function synthetixAdapter() external view returns (ISynthetixAdapter);

    function powerPerp() external view returns (ERC20);

}

interface ISynthetixAdapter {
    function getCurrencyKey(address synth) external view returns (bytes32);

    function getAssetPrice(bytes32 key) external view returns (uint256, bool);
}

contract PowerPerpResolver {
    using FixedPointMathLib for uint256;

    ILiquidityPool liquidityPool;
    IShortCollateral shortCollateral;
    IShortToken shortToken;
    ISynthetixAdapter synthetixAdapter;
    ERC20 powerPerp;


    constructor(address _sysManager) {
        ISystemManager sysManager = ISystemManager(_sysManager);
        liquidityPool = sysManager.pool();
        shortCollateral = sysManager.shortCollateral();
        shortToken = sysManager.shortToken();
        synthetixAdapter = sysManager.synthetixAdapter();
        powerPerp = sysManager.powerPerp();

    }

    function getOrderDetails(int256 amt)
        public
        view
        returns (uint256 fees, uint256 hedgingfees, uint256 tradeFees, uint256 slippageFees)
    {
        fees = liquidityPool.orderFee(amt);
        uint256 valueExchanged = liquidityPool.getMarkPrice().mulWadDown(_abs(amt));
        tradeFees = liquidityPool.getSlippageFee(_abs(amt)).mulWadDown(valueExchanged);
        hedgingfees = fees - tradeFees;
        slippageFees = tradeFees - liquidityPool.baseTradingFee();
    }

    function getLiquidationPrice(uint256 positionId) public view returns (uint256) {
        ShortPosition memory position = shortToken.shortPositions(positionId);
        require(position.shortAmount > 0);

        bytes32 collateralKey = synthetixAdapter.getCurrencyKey(position.collateral);
        Collateral memory collateral = shortCollateral.collaterals(collateralKey);
        (uint256 collateralPrice,) = synthetixAdapter.getAssetPrice(collateralKey);
        // p * s < c * r * amt
        uint256 collateralValue = collateralPrice.mulWadDown(position.collateralAmount).mulWadDown(collateral.liqRatio);
        uint256 liquidationPrice = collateralValue.divWadUp(position.shortAmount);

        return liquidationPrice;
    }

    function getOpenInterest() public view returns (uint256) {
        uint256 totalLongSupply = powerPerp.totalSupply();
        uint256 totalShortSupply = shortToken.totalSupply();
        return (totalLongSupply + totalShortSupply).mulWadDown(liquidityPool.getMarkPrice());
    }

    function _signedAbs(int256 x) internal pure returns (int256) {
        return x < 0 ? -x : x;
    }

    function _abs(int256 x) internal pure returns (uint256) {
        return uint256(_signedAbs(x));
    }
}
