//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import { MemoryInterface, ListInterface, InstaConnectors } from "./interfaces.sol";

abstract contract Stores {

  /**
   * @dev Return ethereum address
   */
  address constant internal ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /**
   * @dev Return Wrapped ETH address
   */
  address constant internal wethAddr = 0x4200000000000000000000000000000000000006;

  /**
   * @dev Return memory variable address
   */
  MemoryInterface constant internal polyMemory = MemoryInterface(0x9f4e24e48D1Cd41FA87A481Ae2242372Bd32618C);

  /**
   * @dev Return InstaList address
   */
  ListInterface internal constant polyList = ListInterface(0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B);

  /**
    * @dev Returns connectors registry address
    */
    InstaConnectors internal constant polyConnectors = InstaConnectors(0x436C89f77F6B6fbFE14d97cd9244e385FaE94FeA);

  /**
   * @dev Get Uint value from InstaMemory Contract.
   */
  function getUint(uint getId, uint val) internal returns (uint returnVal) {
    returnVal = getId == 0 ? val : polyMemory.getUint(getId);
  }

  /**
  * @dev Set Uint value in InstaMemory Contract.
  */
  function setUint(uint setId, uint val) virtual internal {
    if (setId != 0) polyMemory.setUint(setId, val);
  }
}
