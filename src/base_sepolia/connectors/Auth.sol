// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseConnector} from "./BaseConnector.sol";

interface IAccount {
    function isAuth(address user) external view returns (bool);
    function enable(address user) external;
    function disable(address user) external;
}

interface IList {
    struct AccountLink {
        address first;
        address last;
        uint64 count;
    }

    function accountID(address) external view returns (uint64);
    function accountLink(uint64) external view returns (AccountLink memory);
}

contract AuthConnector is BaseConnector {
    string public constant name = "Auth-v1";
    IList public constant list = IList(0x89cd791Bf712673119cdA9ceCf7eAE1cc0C12d0c);

    function enable(address _auth) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(_auth != address(0), "Not-valid-authority");

        IAccount account = IAccount(address(this));

        if (!account.isAuth(_auth)) {
            account.enable(_auth);
        } else {
            _auth = address(0x0);
        }

        _eventName = "LogEnable(address,address)";
        _eventParam = abi.encode(msg.sender, _auth);
    }

    function disable(address _auth) public payable returns (string memory _eventName, bytes memory _eventParam) {
        require(_auth != address(0), "Not-valid-authority");

        uint64 accountId = list.accountID(address(this));
        uint64 count = list.accountLink(accountId).count;
        require(count > 1, "Removing-all-authorities");

        IAccount account = IAccount(address(this));
        if (account.isAuth(_auth)) {
            account.disable(_auth);
        } else {
            _auth = address(0x0);
        }

        _eventName = "LogDisable(address,address)";
        _eventParam = abi.encode(msg.sender, _auth);
    }

    event LogEnable(address indexed _msgSender, address indexed _authority);
    event LogDisable(address indexed _msgSender, address indexed _authority);
}
