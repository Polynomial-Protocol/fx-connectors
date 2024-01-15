// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Auth, Authority} from "solmate/auth/Auth.sol";

contract PolynomialAuthority is Auth, Authority {
    mapping(bytes32 => bool) isAllowed;

    constructor() Auth(msg.sender, Authority(address(0x0))) {}

    function canCall(address user, address target, bytes4 functionSig) public view returns (bool) {
        bytes32 hashCode = keccak256(abi.encode(user, target, functionSig));
        return isAllowed[hashCode];
    }

    function setCapacity(address user, address target, bytes4 functionSig, bool allowed) external requiresAuth {
        bytes32 hashCode = keccak256(abi.encode(user, target, functionSig));
        isAllowed[hashCode] = allowed;
    }

    function setCapacities(address user, bool allowed, address[] memory targets, bytes4[] memory functionSigs)
        external
        requiresAuth
    {
        require(targets.length == functionSigs.length);
        for (uint256 i = 0; i < targets.length; i++) {
            bytes32 hashCode = keccak256(abi.encode(user, targets[i], functionSigs[i]));
            isAllowed[hashCode] = allowed;
        }
    }
}
