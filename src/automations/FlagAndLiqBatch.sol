// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface SynthetixLiquidate {
    function flagPosition(address user) external;

    function liquidatePosition(address user) external;
}

interface ERC20 {
    function balanceOf(address user) external returns (uint256);

    function transfer(address user, uint256 value) external returns (bool);
}

interface IFlagAndLiquidate {
    function flagAndLiqBatch(address, address[] calldata) external;
}

contract FlagAndLiquidate {
    address owner;
    address susd;

    event LogFlag(string message, address user);
    event LogLiquidate(string messsage, address user);

    constructor() {
        owner = msg.sender;
    }

    function flagAndLiqBatch(address market, address[] calldata users) public {
        for (uint i = 0; i < users.length; i++) {
            try SynthetixLiquidate(market).flagPosition(users[i]) {
                emit LogFlag("flagging succeeded for", users[i]);
            } catch {
                emit LogFlag("flagging failed for", users[i]);
            }

            try SynthetixLiquidate(market).liquidatePosition(users[i]) {
                emit LogLiquidate("liquidation succeeded for", users[i]);
            } catch {
                emit LogLiquidate("liquidation failed for", users[i]);
            }
        }
    }

    function transferFunds(address user) public {
        uint256 balance = ERC20(susd).balanceOf(address(this));
        ERC20(susd).transfer(user, balance);
    }
}
