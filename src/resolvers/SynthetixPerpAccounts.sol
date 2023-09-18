// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC721 {
    function balanceOf(address _owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);
}

contract SynthetixPerpAccountsResolver {

    IERC721 public immutable snxPerpAccount;

    constructor(address _snxPerpAccount) {
        snxPerpAccount = IERC721(_snxPerpAccount);
    }

    function getAccounts(address owner) external view returns (uint256[] memory ids) {
        uint256 balance = snxPerpAccount.balanceOf(owner);

        if (balance == 0) {
            ids = new uint256[](1);
            ids[0] = 0;
        } else {
            ids = new uint256[](balance);
            for (uint i = 0; i < balance; i++) {
                ids[i] = snxPerpAccount.tokenOfOwnerByIndex(owner, i);
            }
        }
    }
}