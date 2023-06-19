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
}
