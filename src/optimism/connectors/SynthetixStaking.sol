// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "./BaseConnector.sol";

interface ISynthetix {
    function createAccount(uint128 requestedAccountId) external;

    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external;

    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external;

    function getAccountCollateral(uint128 accountId, address collateralType)
        external
        view
        returns (uint256 totalDeposited, uint256 totalAssigned, uint256 totalLocked);

    function delegateCollateral(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        uint256 amount,
        uint256 leverage
    ) external;
}

interface ISpotMarket {
    struct OrderFees {
        uint256 fixedFees;
        uint256 utilizationFees;
        int256 skewFees;
        int256 wrapperFees;
    }

    function wrap(uint128 marketId, uint256 wrapAmount, uint256 minAmountReceived)
        external
        returns (uint256 amountToMint, OrderFees memory fees);

    function unwrap(uint128 marketId, uint256 unwrapAmount, uint256 minAmountReceived)
        external
        returns (uint256 returnCollateralAmount, OrderFees memory fees);
}

contract SynthetixStakingConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "Synthetix-Staking-v1";
    uint128 public constant USD_MARKET_ID = 1;

    ISynthetix public immutable synthetix;
    ISpotMarket public immutable spotMarket;
    ERC20 public immutable sUSDC;
    ERC20 public immutable USDC;
    uint128 public immutable preferredPoolID;

    constructor(address _synthetix, address _spotMarket, address _susdc, address _usdc, uint128 _preferredPoolID) {
        synthetix = ISynthetix(_synthetix);
        spotMarket = ISpotMarket(_spotMarket);
        sUSDC = ERC20(_susdc);
        USDC = ERC20(_usdc);
        preferredPoolID = _preferredPoolID;
    }

    function createAccount(uint128 requestedAccountId)
        public
        returns (string memory _eventName, bytes memory _eventParam)
    {
        synthetix.createAccount(requestedAccountId);

        _eventName = "LogCreateAccount(uint128)";
        _eventParam = abi.encode(requestedAccountId);
    }

    function deposit(uint128 accountId, uint256 tokenAmount, uint256 getId, uint256 setId)
        public
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _tokenAmount = getUint(getId, tokenAmount);
        if (_tokenAmount == type(uint256).max) {
            _tokenAmount = USDC.balanceOf(address(this));
        }

        USDC.safeApprove(address(spotMarket), _tokenAmount);
        (uint256 synthAmount,) = spotMarket.wrap(USD_MARKET_ID, _tokenAmount, 0);

        sUSDC.safeApprove(address(synthetix), synthAmount);
        synthetix.deposit(accountId, address(sUSDC), synthAmount);

        (, uint256 assignedCollateral,) = synthetix.getAccountCollateral(accountId, address(sUSDC));
        uint256 newCollateral = assignedCollateral + synthAmount;

        // using leverage 1x
        synthetix.delegateCollateral(accountId, preferredPoolID, address(sUSDC), newCollateral, 1 ether);

        setUint(setId, synthAmount);

        _eventName = "LogDeposit(uint128,uint256,uint256,uint256)";
        _eventParam = abi.encode(accountId, _tokenAmount, synthAmount, newCollateral);
    }

    function withdraw(uint128 accountId, uint256 synthAmount, uint256 getId, uint256 setId)
        public
        returns (string memory _eventName, bytes memory _eventParam)
    {
        (, uint256 assignedCollateral,) = synthetix.getAccountCollateral(accountId, address(sUSDC));

        uint256 _synthAmount = getUint(getId, synthAmount);
        if (_synthAmount == type(uint256).max) {
            _synthAmount = assignedCollateral;
        }

        uint256 newCollateral = assignedCollateral - _synthAmount;
        // using leverage 1x
        synthetix.delegateCollateral(accountId, preferredPoolID, address(sUSDC), newCollateral, 1 ether);

        synthetix.withdraw(accountId, address(sUSDC), _synthAmount);

        (uint256 tokenAmount,) = spotMarket.unwrap(USD_MARKET_ID, _synthAmount, 0);

        setUint(setId, tokenAmount);

        _eventName = "LogWithdraw(uint128,uint256,uint256,uint256)";
        _eventParam = abi.encode(accountId, tokenAmount, _synthAmount, newCollateral);
    }

    event LogCreateAccount(uint128 accountId);
    event LogDeposit(uint128 accountId, uint256 tokenAmount, uint256 synthAmount, uint256 newCollateral);
    event LogWithdraw(uint128 accountId, uint256 tokenAmount, uint256 synthAmount, uint256 newCollateral);
}
