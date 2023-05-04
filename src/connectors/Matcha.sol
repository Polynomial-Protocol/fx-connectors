// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BaseConnector} from "../utils/BaseConnector.sol";

struct MatchData {
    ERC20 sellToken;
    ERC20 buyToken;
    uint256 _sellAmt;
    uint256 _buyAmt;
    uint256 unitAmt;
    bytes callData;
}

contract MatchaConnector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "Matcha-v1";
    address internal constant matchaAddr =
        0xDEF1ABE32c034e558Cdd535791643C58a13aCC10;

    /**
     * @notice Swap tokens on 0x
     * @dev Sell ETH/ERC20_Token using 0x.
     * @param from The address of the token to buy.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param to The address of the token to sell.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param amt The amount of the token to sell.
     * @param minReceived The amount of buyAmt/sellAmt with slippage.
     * @param data Data for 0x API.
     * @param setId ID stores the amount of token brought.
     */
    function swap(
        address from,
        address to,
        uint256 amt,
        uint256 minReceived,
        bytes calldata data,
        uint256 setId
    )
        external
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 msgValue;
        ERC20 toToken = ERC20(to);
        uint256 initialBal = to == ethAddr
            ? address(this).balance
            : toToken.balanceOf(address(this));

        if (from == ethAddr) {
            msgValue = amt;
        } else {
            ERC20(from).safeApprove(matchaAddr, amt);
        }

        (bool success, ) = matchaAddr.call{value: msgValue}(data);
        require(success, "swap-failed");

        uint256 finalBal = to == ethAddr
            ? address(this).balance
            : toToken.balanceOf(address(this));
        uint256 received = finalBal - initialBal;
        require(received >= minReceived, "did-not-receive-minimum");

        setUint(setId, received);

        _eventName = "LogSwap(address,address,uint256,uint256,bytes,uint256)";
        _eventParam = abi.encode(from, to, amt, minReceived, data, setId);
    }

    event LogSwap(
        address indexed from,
        address indexed to,
        uint256 amt,
        uint256 minReceived,
        bytes data,
        uint256 setId
    );
}
