// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IWeth {
    function deposit() external payable;
    function withdraw(uint256) external;
}
