// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "../proxy/utils/Initializable.sol";

contract TestEventer is Initializable {
    function emitIt(uint256 value) external {
        emit TheEvent(msg.sender, value, bytes32(value));
    }

    event TheEvent(address indexed user, uint256 value, bytes32 data);
}
