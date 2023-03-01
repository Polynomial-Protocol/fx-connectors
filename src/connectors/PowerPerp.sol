// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "../utils/BaseConnector.sol";

struct TradeParams {
    /// @notice True if the open/close position indicating long
    bool isLong;
    /// @notice Collateral token used. Invalid entry for long positions
    address collateral;
    /// @notice Position ID for short positions. 0 indicating new position
    uint256 positionId;
    /// @notice Amount of power perp longing/shorting
    uint256 amount;
    /// @notice Collateral amount for the position. Invalid entry for long positions
    uint256 collateralAmount;
    uint256 minCost;
    uint256 maxCost;
    bytes32 referralCode;
}

interface ILiquidityPool {
    function deposit(uint256 amount, address user) external;
    function withdraw(uint256 tokens, address user) external;
}

interface IExchange {
    function openTrade(TradeParams memory tradeParams) external returns (uint256 positionId, uint256 totalCost);

    function closeTrade(TradeParams memory tradeParams) external returns (uint256 totalCost);
}

contract PowerPerpConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "Power-Perp";

    ERC20 public constant susd = ERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    ERC20 public constant liquidityToken = ERC20(0x71055Ad10c8B0D5C8d30295CfcE32bE7aA1f1133);
    ERC20 public constant powerPerp = ERC20(0xF80EeBec5A7BeaBE094fd043d55B28D908c12375);
    ERC20 public constant shortToken = ERC20(0x7B15b1EbE6D51e241375FF287476D4379889DDb6);
    address liquidityPool = 0xFEe7e4015e12C6450BEb04784fEf916a31CD79CF;
    address exchange = 0xbd087DfDcf7739B6A6dd8167239273fB3cDcBf92;

    function deposit(uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        _amt = _amt == type(uint256).max ? susd.balanceOf(address(this)) : _amt;
        susd.safeApprove(liquidityPool, _amt);
        ILiquidityPool(liquidityPool).deposit(_amt, address(this));
        setUint(setId, _amt);
        _eventName = "LogDeposit(uint256,uint256,uint256)";
        _eventParam = abi.encode(_amt, getId, setId);
    }

    function withdraw(uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        _amt = _amt == type(uint256).max ? liquidityToken.balanceOf(address(this)) : _amt;
        ILiquidityPool(liquidityPool).withdraw(_amt, address(this));
        setUint(setId, _amt);
        _eventName = "LogWithdraw(uint256,uint256,uint256)";
        _eventParam = abi.encode(_amt, getId, setId);
    }

    function openTrade(TradeParams memory tradeParams, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        (uint256 positionId, uint256 totalCost) = IExchange(exchange).openTrade(tradeParams);
        _eventName = "LogOpenTrade(TradeParams,uint256,uint256)";
        _eventParam = abi.encode(tradeParams, getId, setId);
    }

    function closeTrade(TradeParams memory tradeParams, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, tradeParams.amount);
        if (tradeParams.isLong == true) {
            tradeParams.amount = _amt == type(uint256).max ? powerPerp.balanceOf(address(this)) : _amt;
        } else {
            tradeParams.amount = _amt == type(uint256).max ? shortToken.balanceOf(address(this)) : _amt;
        }
        uint256 totalCost = IExchange(exchange).closeTrade(tradeParams);
        setUint(setId, _amt);
        _eventName = "LogCloseTrade(TradeParams,uint256,uint256)";
        _eventParam = abi.encode(tradeParams, getId, setId);
    }

    event LogDeposit(uint256 amt, uint256 getId, uint256 setId);
    event LogWithdraw(uint256 amt, uint256 getId, uint256 setId);
    event LogOpenTrade(TradeParams tradeParams, uint256 getId, uint256 setId);
    event LogCloseTrade(TradeParams tradeParams, uint256 getId, uint256 setId);
}
