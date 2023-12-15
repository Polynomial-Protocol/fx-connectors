// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IStorage {
    function getUint(uint256 id) external returns (uint256 num);
    function setUint(uint256 id, uint256 val) external;
}

abstract contract BaseConnector {
    IStorage internal constant store = IStorage(0xBD9fB031dAC8FC48e7eB701DDEC90Cc194d5F4Db);

    address internal constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address internal constant wethAddr = 0x4200000000000000000000000000000000000006;

    /**
     * @dev Get Uint value from FxStorage Contract.
     */
    function getUint(uint256 getId, uint256 val) internal returns (uint256 returnVal) {
        returnVal = getId == 0 ? val : store.getUint(getId);
    }

    /**
     * @dev Set Uint value in FxStorage Contract.
     */
    function setUint(uint256 setId, uint256 val) internal virtual {
        if (setId != 0) store.setUint(setId, val);
    }
}
