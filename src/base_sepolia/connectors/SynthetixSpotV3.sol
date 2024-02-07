// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "./BaseConnector.sol";

interface ISpotMarket {
    struct OrderFees {
        uint256 fixedFees;
        uint256 utilizationFees;
        int256 skewFees;
        int256 wrapperFees;
    }

    function getSynth(uint128 marketId) external view returns (ERC20 synth);

    function buyExactOut(uint128 marketId, uint256 synthAmount, uint256 maxUsdAmount, address referrer)
        external
        returns (uint256 usdAmountCharged, OrderFees memory fees);

    function buy(uint128 marketId, uint256 usdAmount, uint256 minAmountReceived, address referrer)
        external
        returns (uint256 synthAmount, OrderFees memory fees);

    function buyExactIn(uint128 marketId, uint256 usdAmount, uint256 minAmountReceived, address referrer)
        external
        returns (uint256 synthAmount, OrderFees memory fees);

    function sell(uint128 marketId, uint256 synthAmount, uint256 minUsdAmount, address referrer)
        external
        returns (uint256 usdAmountReceived, OrderFees memory fees);

    function sellExactIn(uint128 marketId, uint256 synthAmount, uint256 minAmountReceived, address referrer)
        external
        returns (uint256 returnAmount, OrderFees memory fees);

    function sellExactOut(uint128 marketId, uint256 usdAmount, uint256 maxSynthAmount, address referrer)
        external
        returns (uint256 synthToBurn, OrderFees memory fees);

    function wrap(uint128 marketId, uint256 wrapAmount, uint256 minAmountReceived)
        external
        returns (uint256 amountToMint, OrderFees memory fees);

    function unwrap(uint128 marketId, uint256 unwrapAmount, uint256 minAmountReceived)
        external
        returns (uint256 returnCollateralAmount, OrderFees memory fees);
}

contract SynthetixSpotV3Connector is BaseConnector {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    string public constant name = "Synthetix-Spot-v3-v1";

    uint256 public constant WAD = 1e18;

    address public constant referrer = address(bytes20("polynomial"));

    ISpotMarket public immutable spotMarket;

    ERC20 public immutable sUSD;

    ERC20 public immutable USDC;

    constructor(address _spotMarket, address _susd, address _usdc) {
        spotMarket = ISpotMarket(_spotMarket);
        sUSD = ERC20(_susd);
        USDC = ERC20(_usdc);
    }

    function buy(uint128 marketId, uint256 usdAmount, uint256 minAmountReceived, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _usdAmount = getUint(getId, usdAmount);

        if (_usdAmount == type(uint256).max) {
            _usdAmount = sUSD.balanceOf(address(this));
        }

        sUSD.safeApprove(address(spotMarket), _usdAmount);

        (uint256 synthAmount,) = spotMarket.buy(marketId, _usdAmount, minAmountReceived, referrer);

        setUint(setId, synthAmount);

        _eventName = "LogBuy(uint128,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(marketId, _usdAmount, minAmountReceived, getId, setId);
    }

    function buyExactOut(uint128 marketId, uint256 synthAmount, uint256 maxUsdAmount)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        sUSD.safeApprove(address(spotMarket), maxUsdAmount);

        spotMarket.buyExactOut(marketId, synthAmount, maxUsdAmount, referrer);

        sUSD.safeApprove(address(spotMarket), 0);

        _eventName = "LogBuyExactOut(uint128,uint256,uint256)";
        _eventParam = abi.encode(marketId, synthAmount, maxUsdAmount);
    }

    function sell(uint128 marketId, uint256 synthAmount, uint256 minUsdAmount, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _synthAmount = getUint(getId, synthAmount);

        if (_synthAmount == type(uint256).max) {
            ERC20 synth = spotMarket.getSynth(marketId);
            _synthAmount = synth.balanceOf(address(this));
        }

        (uint256 usdAmountReceived,) = spotMarket.sell(marketId, _synthAmount, minUsdAmount, referrer);

        setUint(setId, usdAmountReceived);

        _eventName = "LogSell(uint128,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(marketId, _synthAmount, minUsdAmount, getId, setId);
    }

    function sellExactOut(uint128 marketId, uint256 usdAmount, uint256 maxSynthAmount)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        spotMarket.sellExactOut(marketId, usdAmount, maxSynthAmount, referrer);

        _eventName = "LogSellExactOut(uint128,uint256,uint256)";
        _eventParam = abi.encode(marketId, usdAmount, maxSynthAmount);
    }

    function wrapUSDC(uint128 marketId, uint256 wrapAmount, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _wrapAmount = getUint(getId, wrapAmount);

        if (_wrapAmount == type(uint256).max) {
            _wrapAmount = USDC.balanceOf(address(this));
        }

        USDC.safeApprove(address(spotMarket), _wrapAmount);

        (uint256 sUSDCAmount,) = spotMarket.wrap(marketId, _wrapAmount, _wrapAmount);

        (uint256 usdAmountReceived,) = spotMarket.sell(marketId, sUSDCAmount, sUSDCAmount, referrer);

        setUint(setId, usdAmountReceived);

        _eventName = "LogWrapUSDC(uint128,uint256)";
        _eventParam = abi.encode(marketId, _wrapAmount);
    }

    function unwrapUSDC(uint128 marketId, uint256 unwrapAmount, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _unwrapAmount = getUint(getId, unwrapAmount);

        if (_unwrapAmount == type(uint256).max) {
            _unwrapAmount = sUSD.balanceOf(address(this));
        }

        sUSD.safeApprove(address(spotMarket), _unwrapAmount);

        (uint256 synthAmount,) = spotMarket.buy(marketId, _unwrapAmount, _unwrapAmount, referrer);

        (uint256 returnCollateralAmount,) =
            spotMarket.unwrap(marketId, synthAmount, _getAmtInDecimals(synthAmount, USDC.decimals()));

        setUint(setId, returnCollateralAmount);

        _eventName = "LogUnWrapUSDC(uint128,uint256)";
        _eventParam = abi.encode(marketId, unwrapAmount);
    }

    function _getAmtInDecimals(uint256 amt, uint8 decimals) internal pure returns (uint256 _amt) {
        if (decimals >= 18) {
            uint256 multiplier = 10 ** (decimals - 18);
            _amt = amt * multiplier;
        } else {
            uint256 divider = 10 ** (18 - decimals);
            _amt = amt / divider;
        }
    }

    event LogBuy(uint128 marketId, uint256 usdAmount, uint256 minAmountReceived, uint256 getId, uint256 setId);
    event LogBuyExactOut(uint128 marketId, uint256 synthAmount, uint256 maxUsdAmount);
    event LogSell(uint128 marketId, uint256 synthAmount, uint256 minUsdAmount, uint256 getId, uint256 setId);
    event LogSellExactOut(uint128 marketId, uint256 usdAmount, uint256 maxSynthAmount);
    event LogWrapUSDC(uint128 marketId, uint256 wrapAmount);
    event LogUnWrapUSDC(uint128 marketId, uint256 unwrapAmount);
}
