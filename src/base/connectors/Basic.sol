// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "./BaseConnector.sol";

contract BasicConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "Basic-v1";

    function deposit(address token, uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        if (token != ethAddr) {
            ERC20 _token = ERC20(token);
            _amt = _amt == type(uint256).max ? _token.balanceOf(msg.sender) : _amt;
            _token.safeTransferFrom(msg.sender, address(this), _amt);
        } else {
            require(msg.value == _amt || _amt == type(uint256).max, "invalid-ether-amount");
            _amt = msg.value;
        }
        setUint(setId, _amt);

        _eventName = "LogDeposit(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, _amt, getId, setId);
    }

    function depositFrom(address token, uint256 amt, address from, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        require(token != ethAddr, "eth-not-supported");
        ERC20 _token = ERC20(token);
        _amt = _amt == type(uint256).max ? _token.balanceOf(from) : _amt;
        _token.safeTransferFrom(from, address(this), _amt);

        setUint(setId, _amt);

        _eventName = "LogDepositFrom(address,uint256,address,uint256,uint256)";
        _eventParam = abi.encode(token, _amt, from, getId, setId);
    }

    function withdraw(address token, uint256 amt, address payable to, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);
        if (token == ethAddr) {
            _amt = _amt == type(uint256).max ? address(this).balance : _amt;
            to.call{value: _amt}("");
        } else {
            ERC20 _token = ERC20(token);
            _amt = _amt == type(uint256).max ? _token.balanceOf(address(this)) : _amt;
            _token.safeTransfer(to, _amt);
        }
        setUint(setId, _amt);

        _eventName = "LogWithdraw(address,uint256,address,uint256,uint256)";
        _eventParam = abi.encode(token, _amt, to, getId, setId);
    }
    
    function permit(address token, address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        ERC20(token).permit(owner, spender, value, deadline, v, r, s);
    }

    event LogDeposit(address indexed erc20, uint256 tokenAmt, uint256 getId, uint256 setId);
    event LogWithdraw(address indexed erc20, uint256 tokenAmt, address indexed to, uint256 getId, uint256 setId);
    event LogDepositFrom(address indexed erc20, uint256 tokenAmt, address indexed from, uint256 getId, uint256 setId);
}
