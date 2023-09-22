// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "../utils/BaseConnector.sol";

interface ISpotMarket {
    function getSynth(uint128 marketId) external view returns (ERC20 synth);
}

interface IPerpMarket {
    struct OrderCommitmentRequest {
        uint128 marketId;
        uint128 accountId;
        int128 sizeDelta;
        uint128 settlementStrategyId;
        uint256 acceptablePrice;
        bytes32 trackingCode;
        address referrer;
    }

    function getCollateralAmount(uint128 accountId, uint128 synthMarketId) external view returns (uint256);

    function createAccount(uint128 requestedAccountId) external;

    function modifyCollateral(uint128 accountId, uint128 synthMarketId, int256 amountDelta) external;

    function commitOrder(OrderCommitmentRequest memory commitment) external;

    function settlePythOrder(bytes calldata result, bytes calldata extraData) external payable;

    function getOpenPosition(uint128 accountId, uint128 marketId)
        external
        view
        returns (int256 totalPnl, int256 accruedFunding, int128 positionSize);
}

contract SynthetixPerpV3Connector is BaseConnector {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    string public constant name = "Synthetix-Perp-v3-v1";

    uint256 public constant WAD = 1e18;

    IPerpMarket public immutable perpMarket;

    ISpotMarket public immutable spotMarket;

    ERC20 public immutable sUSD;

    constructor(address _perpMarket, address _spotMarket, address _susd) {
        perpMarket = IPerpMarket(_perpMarket);
        spotMarket = ISpotMarket(_spotMarket);
        sUSD = ERC20(_susd);
    }

    function createAccount(uint128 id) public payable returns (string memory _eventName, bytes memory _eventParam) {
        perpMarket.createAccount(id);

        _eventName = "LogCreateAccount(uint128)";
        _eventParam = abi.encode(id);
    }

    function addCollateral(uint128 accountId, uint128 synthMarketId, uint256 amount, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        ERC20 synth;
        uint256 _amt = getUint(getId, amount);
        if (synthMarketId == 0) {
            synth = sUSD;
            _amt = _amt == type(uint256).max ? sUSD.balanceOf(address(this)) : _amt;
        } else {
            synth = spotMarket.getSynth(synthMarketId);
            _amt = _amt == type(uint256).max ? synth.balanceOf(address(this)) : _amt;
        }

        synth.safeApprove(address(perpMarket), _amt);
        perpMarket.modifyCollateral(accountId, synthMarketId, int256(_amt));

        setUint(setId, _amt);

        _eventName = "LogAddCollateral(uint128,uint128,uint256,uint256, uint256)";
        _eventParam = abi.encode(accountId, synthMarketId, amount, getId, setId);
    }

    function removeCollateral(uint128 accountId, uint128 synthMarketId, uint256 amount, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amount);
        _amt = _amt == type(uint256).max ? perpMarket.getCollateralAmount(accountId, synthMarketId) : _amt;

        perpMarket.modifyCollateral(accountId, synthMarketId, -int256(_amt));

        setUint(setId, _amt);

        _eventName = "LogRemoveCollateral(uint128,uint128,uint256,uint256, uint256)";
        _eventParam = abi.encode(accountId, synthMarketId, amount, getId, setId);
    }

    function modifyCollateral(uint128 accountId, uint128 synthMarketId, int256 amount)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        if (synthMarketId != 0 && amount > 0) {
            ERC20 synth = spotMarket.getSynth(synthMarketId);
            synth.safeApprove(address(perpMarket), uint256(amount));
        }
        perpMarket.modifyCollateral(accountId, synthMarketId, amount);

        _eventName = "LogModifyCollateral(uint128,uint128,int256)";
        _eventParam = abi.encode(accountId, synthMarketId, amount);
    }

    function long(
        uint128 accountId,
        uint128 marketId,
        uint128 size,
        uint256 acceptablePrice,
        uint256 getId,
        uint256 setId
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 sizeDelta = getUint(getId, size);

        IPerpMarket.OrderCommitmentRequest memory data = IPerpMarket.OrderCommitmentRequest(
            marketId, accountId, int128(int256(sizeDelta)), 0, acceptablePrice, "polynomial", address(0x0)
        );

        perpMarket.commitOrder(data);

        setUint(setId, sizeDelta);

        _eventName = "LogLong(uint128,uint128,int128,uint256,uint256,uint256)";
        _eventParam = abi.encode(accountId, marketId, size, acceptablePrice, getId, setId);
    }

    function short(
        uint128 accountId,
        uint128 marketId,
        uint128 size,
        uint256 acceptablePrice,
        uint256 getId,
        uint256 setId
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 sizeDelta = getUint(getId, size);

        IPerpMarket.OrderCommitmentRequest memory data = IPerpMarket.OrderCommitmentRequest(
            marketId, accountId, -int128(int256(sizeDelta)), 0, acceptablePrice, "polynomial", address(0x0)
        );

        perpMarket.commitOrder(data);

        setUint(setId, sizeDelta);

        _eventName = "LogShort(uint128,uint128,int128,uint256,uint256,uint256)";
        _eventParam = abi.encode(accountId, marketId, size, acceptablePrice, getId, setId);
    }

    function close(uint128 accountId, uint128 marketId, uint256 acceptablePrice)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        (,, int128 positionSize) = perpMarket.getOpenPosition(accountId, marketId);

        IPerpMarket.OrderCommitmentRequest memory data = IPerpMarket.OrderCommitmentRequest(
            marketId, accountId, -int128(positionSize), 0, acceptablePrice, "polynomial", address(0x0)
        );

        perpMarket.commitOrder(data);

        _eventName = "LogClose(uint128,uint128,uint256)";
        _eventParam = abi.encode(accountId, marketId, acceptablePrice);
    }

    function commitTrade(uint128 accountId, uint128 marketId, int128 sizeDelta, uint256 acceptablePrice)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        IPerpMarket.OrderCommitmentRequest memory data = IPerpMarket.OrderCommitmentRequest(
            marketId, accountId, sizeDelta, 0, acceptablePrice, "polynomial", address(0x0)
        );

        perpMarket.commitOrder(data);

        _eventName = "LogCommitTrade(uint128,uint128,int128,uint256)";
        _eventParam = abi.encode(accountId, marketId, sizeDelta, acceptablePrice);
    }

    function settleTrade(uint128 accountId, bytes memory updateData)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        bytes memory extraData = abi.encode(accountId);

        perpMarket.settlePythOrder{value: msg.value}(updateData, extraData);

        _eventName = "LogSettleTrade(uint128,bytes)";
        _eventParam = abi.encode(accountId, updateData);
    }

    event LogAddCollateral(uint128, uint128, uint256, uint256, uint256);
    event LogRemoveCollateral(uint128, uint128, uint256, uint256, uint256);
    event LogModifyCollateral(uint128, uint128, int256);
    event LogLong(uint128, uint128, int128, uint256, uint256, uint256);
    event LogShort(uint128, uint128, int128, uint256, uint256, uint256);
    event LogCommitTrade(uint128, uint128, int128, uint256);
    event LogClose(uint128, uint128, uint256);
    event LogSettleTrade(uint128, bytes);
}
