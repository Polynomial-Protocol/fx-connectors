// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BaseConnector} from "../utils/BaseConnector.sol";

interface IEmitter {
    function emitSwap(address from, address to, uint256 amt, uint256 minReceived, uint256 received) external;
}

contract MatchaConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    struct Data {
        uint256 msgValue;
        uint256 initialBal;
        uint256 finalBal;
        ERC20 toToken;
    }

    string public constant name = "Matcha-v1";
    address internal constant matchaAddr = 0xDEF1ABE32c034e558Cdd535791643C58a13aCC10;
    IEmitter internal constant emitter = IEmitter(0x0Be3A0E2944b1C43799E2d447d1367A397c4F573);

    /**
     * @notice Swap tokens on 0x
     * @dev Sell ETH/ERC20_Token using 0x.
     * @param from The address of the token to buy.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param to The address of the token to sell.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt The amount of the token to sell.
     * @param minReceived The amount of buyAmt/sellAmt with slippage.
     * @param data_ Data for 0x API.
     * @param setId ID stores the amount of token brought.
     */
    function swap(address from, address to, uint256 amt, uint256 minReceived, bytes calldata data_, uint256 setId)
        external
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        Data memory data;
        data.toToken = ERC20(to);
        data.initialBal = to == ethAddr ? address(this).balance : data.toToken.balanceOf(address(this));

        if (from == ethAddr) {
            data.msgValue = amt;
        } else {
            ERC20(from).safeApprove(matchaAddr, amt);
        }

        (bool success,) = matchaAddr.call{value: data.msgValue}(data_);
        require(success, "swap-failed");

        data.finalBal = to == ethAddr ? address(this).balance : data.toToken.balanceOf(address(this));
        uint256 received = data.finalBal - data.initialBal;
        require(received >= minReceived, "did-not-receive-minimum");

        setUint(setId, received);

        emitter.emitSwap(from, to, amt, minReceived, received);

        _eventName = "LogSwap(address,address,uint256,uint256,bytes,uint256)";
        _eventParam = abi.encode(from, to, amt, minReceived, data_, setId);
    }

    event LogSwap(
        address indexed from, address indexed to, uint256 amt, uint256 minReceived, bytes data, uint256 setId
    );
}
