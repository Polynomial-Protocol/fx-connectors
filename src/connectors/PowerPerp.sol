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
    function queueDeposit(uint256 amount, address user) external;
    function queueWithdraw(uint256 amount, address user) external;
    function deposit(uint256 amount, address user) external;
    function withdraw(uint256 tokens, address user) external;
}

interface IExchange {
    function openTrade(TradeParams memory tradeParams) external returns (uint256 positionId, uint256 totalCost);

    function closeTrade(TradeParams memory tradeParams) external returns (uint256 totalCost);
}

contract PowerPerpConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "Power-Perp-v1";

    ERC20 public constant susd = ERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);
    ERC20 public immutable liquidityToken;
    ERC20 public immutable powerPerp;
    ERC20 public immutable shortToken;

    address immutable liquidityPool;
    address immutable exchange;

    constructor(
        address _liquidityToken,
        address _powerPerp,
        address _shortToken,
        address _liquidityPool,
        address _exchange
    ) {
        liquidityPool = _liquidityPool;
        exchange = _exchange;
        liquidityToken = ERC20(_liquidityToken);
        powerPerp = ERC20(_powerPerp);
        shortToken = ERC20(_shortToken);
    }

    function initiateDeposit(uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        _amt = _amt == type(uint256).max ? susd.balanceOf(address(this)) : _amt;
        susd.safeApprove(liquidityPool, _amt);
        ILiquidityPool(liquidityPool).queueDeposit(_amt, address(this));
        setUint(setId, _amt);
        _eventName = "LogInitiateDeposit(uint256,uint256,uint256)";
        _eventParam = abi.encode(_amt, getId, setId);
    }

    function initiateWithdraw(uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        _amt = _amt == type(uint256).max ? liquidityToken.balanceOf(address(this)) : _amt;
        ILiquidityPool(liquidityPool).queueWithdraw(_amt, address(this));
        setUint(setId, _amt);
        _eventName = "LogInitiateWithdraw(uint256,uint256,uint256)";
        _eventParam = abi.encode(_amt, getId, setId);
    }

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

    event LogInitiateDeposit(uint256 amt, uint256 getId, uint256 setId);
    event LogInitiateWithdraw(uint256 amt, uint256 getId, uint256 setId);
    event LogDeposit(uint256 amt, uint256 getId, uint256 setId);
    event LogWithdraw(uint256 amt, uint256 getId, uint256 setId);
    event LogOpenTrade(TradeParams tradeParams, uint256 getId, uint256 setId);
    event LogCloseTrade(TradeParams tradeParams, uint256 getId, uint256 setId);
}
