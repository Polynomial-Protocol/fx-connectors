// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BaseConnector} from "../utils/BaseConnector.sol";

interface IExclusiveImpl {
    function enableAdditionalAuth(address _user, uint256 _expiry) external;

    function disableAdditionalAuth(address user) external;
}

interface IDefaultImpl {
    function toggleBeta() external;

    function isBeta() external returns (bool);
}

contract OneClickTrading is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "One-Click-Trading-v1";

    function enableAuth(address _user, uint256 _expiry)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        IExclusiveImpl(address(this)).enableAdditionalAuth(_user, _expiry);
        _eventName = "LogEnableAuth(address,uint256)";
        _eventParam = abi.encode(_user, _expiry);
    }

    function disableAuth(address _user) public payable returns (string memory _eventName, bytes memory _eventParam) {
        IExclusiveImpl(address(this)).disableAdditionalAuth(_user);
        _eventName = "LogDisableAuth(address)";
        _eventParam = abi.encode(_user);
    }

    function toggleBeta() public payable returns (string memory _eventName, bytes memory _eventParam){
        IDefaultImpl(address(this)).toggleBeta();
        _eventName = "LogToggleBeta(address,bool)";
        _eventParam = abi.encode(address(this), IDefaultImpl(address(this)).isBeta());
    }

    event LogEnableAuth(address indexed _user, uint256 _expiry);
    event LogDisableAuth(address indexed _user);
    event LogToggleBeta(address indexed _address, bool _betaStatus);
}
