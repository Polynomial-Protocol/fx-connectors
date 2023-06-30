// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "../proxy/utils/Initializable.sol";

interface IList {
    function accountID(address) external view returns (uint64);
}

contract PolyEmitter is Initializable {
    constructor() {
        _disableInitializers();
    }

    function emitSwap(address from, address to, uint256 amt, uint256 minReceived, uint256 received) external onlyScw {
        emit Swap(msg.sender, from, to, amt, minReceived, received);
    }

    function emitAaveDeposit(address token, uint256 amt) external onlyScw {
        emit AaveDeposit(msg.sender, token, amt);
    }

    function emitAaveWithdraw(address token, uint256 amt) external onlyScw {
        emit AaveWithdraw(msg.sender, token, amt);
    }

    function emitAaveBorrow(address token, uint256 amt) external onlyScw {
        emit AaveBorrow(msg.sender, token, amt);
    }

    function emitAavePayback(address token, uint256 amt) external onlyScw {
        emit AavePayback(msg.sender, token, amt);
    }

    modifier onlyScw() {
        require(IList(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B).accountID(msg.sender) != 0);
        _;
    }

    event Swap(
        address indexed user,
        address indexed from,
        address indexed to,
        uint256 amt,
        uint256 minReceived,
        uint256 received
    );

    event AaveDeposit(address indexed user, address indexed token, uint256 amt);

    event AaveWithdraw(address indexed user, address indexed token, uint256 amt);

    event AaveBorrow(address indexed user, address indexed token, uint256 amt);

    event AavePayback(address indexed user, address indexed token, uint256 amt);
}
