// SPDX-License-Identifier: AGPL-3.0-only
// Source - https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol

pragma solidity >=0.8.0;

import {Initializable} from "../proxy/utils/Initializable.sol";

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuardUpgradable is Initializable {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private locked;

    function _reentrancy_init() internal onlyInitializing {
        locked = _NOT_ENTERED;
    }

    modifier nonReentrant() virtual {
        require(locked == _NOT_ENTERED, "REENTRANCY");

        locked = 2;

        _;

        locked = 1;
    }
}
