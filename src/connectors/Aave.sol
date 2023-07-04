// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "../utils/BaseConnector.sol";

import {IWeth} from "../interfaces/IWeth.sol";

interface IEmitter {
    function emitAaveDeposit(address token, uint256 amt) external;
    function emitAaveWithdraw(address token, uint256 amt) external;
    function emitAaveBorrow(address token, uint256 amt) external;
    function emitAavePayback(address token, uint256 amt) external;
}

interface IAave {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
}

interface IAavePoolProvider {
    function getPool() external view returns (address);
}

interface IAaveData {
    function getUserReserveData(address _asset, address _user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );
}

contract AaveConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "Aave-v3-v1";

    IAavePoolProvider public constant aaveProvider = IAavePoolProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
    IAaveData public constant aaveData = IAaveData(0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654);
    IEmitter internal constant emitter = IEmitter(0x0Be3A0E2944b1C43799E2d447d1367A397c4F573);

    function deposit(address token, uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 amt_ = getUint(getId, amt);

        IAave aave = IAave(aaveProvider.getPool());

        bool isEth = token == ethAddr;
        ERC20 token_ = isEth ? ERC20(wethAddr) : ERC20(token);

        if (isEth) {
            amt_ = amt_ == type(uint256).max ? address(this).balance : amt_;
            IWeth(wethAddr).deposit{value: amt_}();
        } else {
            amt_ = amt_ == type(uint256).max ? token_.balanceOf(address(this)) : amt_;
        }

        token_.safeApprove(address(aave), amt_);

        aave.supply(address(token_), amt_, address(this), 0);
        if (!getIsColl(address(token_))) {
            aave.setUserUseReserveAsCollateral(address(token_), true);
        }

        setUint(setId, amt_);

        emitter.emitAaveDeposit(token, amt_);

        _eventName = "LogDeposit(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, amt_, getId, setId);
    }

    function withdraw(address token, uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 amt_ = getUint(getId, amt);

        IAave aave = IAave(aaveProvider.getPool());

        bool isEth = token == ethAddr;
        ERC20 token_ = isEth ? ERC20(wethAddr) : ERC20(token);

        uint256 balBefore = token_.balanceOf(address(this));
        aave.withdraw(address(token_), amt_, address(this));
        uint256 balAfter = token_.balanceOf(address(this));

        amt_ = balAfter - balBefore;

        if (isEth) {
            IWeth(wethAddr).withdraw(amt_);
        }

        setUint(setId, amt_);

        emitter.emitAaveWithdraw(token, amt_);

        _eventName = "LogWithdraw(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, amt_, getId, setId);
    }

    function borrow(address token, uint256 amt, uint256 rateMode, uint256 getId, uint256 setId)
        external
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 amt_ = getUint(getId, amt);

        IAave aave = IAave(aaveProvider.getPool());

        bool isEth = token == ethAddr;
        ERC20 token_ = isEth ? ERC20(wethAddr) : ERC20(token);

        aave.borrow(address(token_), amt_, rateMode, 0, address(this));

        if (isEth) {
            IWeth(wethAddr).withdraw(amt_);
        }

        setUint(setId, amt_);

        emitter.emitAaveBorrow(token, amt_);

        _eventName = "LogBorrow(address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, amt_, rateMode, getId, setId);
    }

    function payback(address token, uint256 amt, uint256 rateMode, uint256 getId, uint256 setId)
        external
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 amt_ = getUint(getId, amt);

        IAave aave = IAave(aaveProvider.getPool());

        bool isEth = token == ethAddr;
        ERC20 token_ = isEth ? ERC20(wethAddr) : ERC20(token);

        amt_ = amt_ == type(uint256).max ? getPaybackBalance(address(token_), rateMode) : amt_;

        if (isEth) {
            IWeth(wethAddr).deposit{value: amt_}();
        }

        token_.safeApprove(address(aave), amt_);
        aave.repay(address(token_), amt_, rateMode, address(this));

        setUint(setId, amt_);

        emitter.emitAavePayback(token, amt_);

        _eventName = "LogPayback(address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, amt_, rateMode, getId, setId);
    }

    function getIsColl(address token) internal view returns (bool isCol) {
        (,,,,,,,, isCol) = aaveData.getUserReserveData(token, address(this));
    }

    function getPaybackBalance(address token, uint256 rateMode) internal view returns (uint256) {
        (, uint256 stableDebt, uint256 variableDebt,,,,,,) = aaveData.getUserReserveData(token, address(this));
        return rateMode == 1 ? stableDebt : variableDebt;
    }

    event LogDeposit(address indexed token, uint256 tokenAmt, uint256 getId, uint256 setId);
    event LogWithdraw(address indexed token, uint256 tokenAmt, uint256 getId, uint256 setId);
    event LogBorrow(address indexed token, uint256 tokenAmt, uint256 indexed rateMode, uint256 getId, uint256 setId);
    event LogPayback(address indexed token, uint256 tokenAmt, uint256 indexed rateMode, uint256 getId, uint256 setId);
}
