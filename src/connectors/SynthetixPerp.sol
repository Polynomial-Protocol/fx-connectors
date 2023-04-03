// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {BaseConnector} from "../utils/BaseConnector.sol";

interface IPerpMarket {
    struct Position {
        uint64 id;
        uint64 lastFundingIndex;
        uint128 margin;
        uint128 lastPrice;
        int128 size;
    }

    function assetPrice() external view returns (uint256 price, bool invalid);

    function positions(address account) external view returns (Position memory);

    function transferMargin(int256 marginDelta) external;

    function withdrawAllMargin() external;

    function submitOffchainDelayedOrderWithTracking(int256 sizeDelta, uint256 priceImpactDelta, bytes32 trackingCode)
        external;

    function cancelOffchainDelayedOrder(address account) external;
}

contract SynthetixPerpConnector is BaseConnector {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    string public constant name = "Synthetix-Perp-v1.3";

    ERC20 public constant susd = ERC20(0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9);

    uint256 public constant WAD = 1e18;

    function addMargin(address market, uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        _amt = _amt == type(uint256).max ? susd.balanceOf(address(this)) : _amt;

        int256 marginDelta = int256(_amt);
        IPerpMarket(market).transferMargin(marginDelta);

        setUint(setId, _amt);

        _eventName = "LogAddMargin(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(market, _amt, getId, setId);
    }

    function removeMargin(address market, uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        if (_amt == type(uint256).max) {
            uint256 preWithdraw = susd.balanceOf(address(this));
            IPerpMarket(market).withdrawAllMargin();
            uint256 postWithdraw = susd.balanceOf(address(this));
            _amt = postWithdraw - preWithdraw;
        } else {
            int256 marginDelta = -int256(_amt);
            IPerpMarket(market).transferMargin(marginDelta);
        }

        setUint(setId, _amt);

        _eventName = "LogRemoveMargin(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(market, _amt, getId, setId);
    }

    function trade(address market, int256 sizeDelta, uint256 slippage)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        (uint256 price, bool invalid) = IPerpMarket(market).assetPrice();

        require(!invalid);

        uint256 desiredPrice = sizeDelta > 0 ? price.mulWadDown(WAD + slippage) : price.mulWadDown(WAD - slippage);

        IPerpMarket(market).submitOffchainDelayedOrderWithTracking(sizeDelta, desiredPrice, "polynomial");

        _eventName = "LogTrade(address,int256,uint256)";
        _eventParam = abi.encode(market, sizeDelta, slippage);
    }

    function closeTrade(address market, uint256 slippage)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        IPerpMarket.Position memory position = IPerpMarket(market).positions(address(this));
        int256 sizeDelta = -position.size;

        (uint256 price, bool invalid) = IPerpMarket(market).assetPrice();

        require(!invalid);

        uint256 desiredPrice = sizeDelta > 0 ? price.mulWadDown(WAD + slippage) : price.mulWadDown(WAD - slippage);

        IPerpMarket(market).submitOffchainDelayedOrderWithTracking(sizeDelta, desiredPrice, "polynomial");

        _eventName = "LogClose(address,int256,uint256)";
        _eventParam = abi.encode(market, sizeDelta, slippage);
    }

    function long(address market, uint256 longSize, uint256 slippage, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _longSize = getUint(getId, longSize);

        (uint256 price, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid);

        uint256 desiredPrice = price.mulWadDown(WAD + slippage);

        int256 sizeDelta = int256(_longSize);
        IPerpMarket(market).submitOffchainDelayedOrderWithTracking(sizeDelta, desiredPrice, "polynomial");
        setUint(setId, _longSize);

        _eventName = "LogLong(address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(market, _longSize, slippage, getId, setId);
    }

    function short(address market, uint256 shortSize, uint256 slippage, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _shortSize = getUint(getId, shortSize);

        (uint256 price, bool invalid) = IPerpMarket(market).assetPrice();
        require(!invalid);

        uint256 desiredPrice = price.mulWadDown(WAD - slippage);

        int256 sizeDelta = -int256(_shortSize);
        IPerpMarket(market).submitOffchainDelayedOrderWithTracking(sizeDelta, desiredPrice, "polynomial");
        setUint(setId, _shortSize);

        _eventName = "LogShort(address,uint256,uint256,uint256,uint256)";
        _eventParam = abi.encode(market, _shortSize, slippage, getId, setId);
    }

    function cancelOrder(address market) public payable returns (string memory _eventName, bytes memory _eventParam) {
        IPerpMarket(market).cancelOffchainDelayedOrder(address(this));

        _eventName = "LogCancel(address)";
        _eventParam = abi.encode(market);
    }

    event LogAddMargin(address indexed market, uint256 amt, uint256 getId, uint256 setId);
    event LogRemoveMargin(address indexed market, uint256 amt, uint256 getId, uint256 setId);
    event LogTrade(address indexed market, int256 sizeDelta, uint256 slippage);
    event LogClose(address indexed market, int256 sizeDelta, uint256 slippage);
    event LogLong(address indexed market, uint256 longSize, uint256 slippage, uint256 getId, uint256 setId);
    event LogShort(address indexed market, uint256 shortSize, uint256 slippage, uint256 getId, uint256 setId);
    event LogCancel(address indexed market);
}
