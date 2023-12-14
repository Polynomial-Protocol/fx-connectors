// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BaseConnector} from "../utils/BaseConnector.sol";

interface IEmitter {
    function emitSwap(address from, address to, uint256 amt, uint256 minReceived, uint256 received) external;
}

interface IExclusiveImpl {
    function enableAdditionalAuth(address _user, uint256 _expiry) external;
        
    function disableAdditionalAuth(address user) external;
}

interface IDefaultImpl {
    function toggleBeta() external;

    function isBeta() external returns(bool);
}

contract OneClickTrading is BaseConnector {
    using SafeTransferLib for ERC20;

    struct Data {
        uint256 msgValue;
        uint256 initialBal;
        uint256 finalBal;
        ERC20 toToken;
    }

    string public constant name = "One-Click-Trading-v1";
    
    function enableAuth(address _user, uint256 _expiry) public payable {
        IExclusiveImpl(address(this)).enableAdditionalAuth(_user, _expiry);
    }
    
    function disableAuth(address _user) public payable {
        IExclusiveImpl(address(this)).disableAdditionalAuth(_user);
    }
    
    function toggleBeta() public payable {
        IDefaultImpl(address(this)).toggleBeta();
    }
    
    function isBeta() public payable returns (bool){
        return IDefaultImpl(address(this)).isBeta();
    }
    
    event LogSwap(
        address indexed from, address indexed to, uint256 amt, uint256 minReceived, bytes data, uint256 setId
    );
}
