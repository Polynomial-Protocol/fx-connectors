// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "./BaseConnector.sol";

interface IFee {
    function deposit(uint256 amt) external;
    function claim(uint64[] memory _actions) external;
}

contract FeeConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "Fee-v1";

    ERC20 public immutable USDC;
    IFee public immutable fee;

    constructor(address _usdc, address _fee) {
        USDC = ERC20(_usdc);
        fee = IFee(_fee);
    }

    function deposit(uint256 amount, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amount = getUint(getId, amount);

        if (_amount == type(uint256).max) {
            _amount = USDC.balanceOf(address(this));
        }

        USDC.safeApprove(address(fee), _amount);
        fee.deposit(_amount);

        setUint(setId, _amount);

        _eventName = "LogDeposit(uint256,uint256,uint256)";
        _eventParam = abi.encode(_amount, getId, setId);
    }

    function claim(uint64[] memory actions)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        fee.claim(actions);

        _eventName = "LogClaim(uint64[])";
        _eventParam = abi.encode(actions);
    }

    event LogDeposit(uint256 amount, uint256 getId, uint256 setId);
    event LogClaim(uint64[] actions);
}
