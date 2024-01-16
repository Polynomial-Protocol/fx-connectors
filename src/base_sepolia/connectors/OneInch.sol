// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {BaseConnector} from "../../common/utils/BaseConnector.sol";

contract OneInchConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "1inch-v5-v1";

    address public constant oneInch = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    function swap(address from, address to, uint256 amt, uint256 minReceived, bytes memory data, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 msgValue;
        ERC20 toToken = ERC20(to);
        uint256 initialBal = to == ethAddr ? address(this).balance : toToken.balanceOf(address(this));

        if (from == ethAddr) {
            msgValue = amt;
        } else {
            ERC20(from).safeApprove(oneInch, amt);
        }

        (bool success,) = oneInch.call{value: msgValue}(data);
        require(success, "swap-failed");

        uint256 finalBal = to == ethAddr ? address(this).balance : toToken.balanceOf(address(this));
        uint256 received = finalBal - initialBal;
        require(received >= minReceived, "did-not-receive-minimum");

        setUint(setId, received);

        _eventName = "LogSwap(address,address,uint256,uint256,bytes,uint256)";
        _eventParam = abi.encode(from, to, amt, minReceived, data, setId);
    }

    event LogSwap(
        address indexed from, address indexed to, uint256 amt, uint256 minReceived, bytes data, uint256 setId
    );
}
