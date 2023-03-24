// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseConnector} from "../utils/BaseConnector.sol";

interface ILiquidityProtection {
    function updateProtection(address[] memory _markets, bool[] memory _actions, uint256[] memory _thresholds)
        external;
}

interface IAccount {
    function isAuth(address user) external view returns (bool);
    function enable(address user) external;
    function disable(address user) external;
}

contract SynthetixPerpLimitOrderConnector is BaseConnector {
    ILiquidityProtection public constant liquidityProtection = ILiquidityProtection(address(0x0));

    string public constant name = "Synthetix-Perp-Liquidity-Protection-v1";

    function updateProtection(address[] memory markets, bool[] memory actions, uint256[] memory thresholds)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        bool isAuth = IAccount(address(this)).isAuth(address(liquidityProtection));

        if (!isAuth) {
            IAccount(address(this)).enable(address(liquidityProtection));
        }

        liquidityProtection.updateProtection(markets, actions, thresholds);

        _eventName = "LogUpdateProtection(address[], bool[], uint256[])";
        _eventParam = abi.encode(markets, actions, thresholds);
    }

    event LogUpdateProtection(address[] markets, bool[] actions, uint256[] thresholds);
}
