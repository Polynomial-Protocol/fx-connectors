// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseConnector} from "../utils/BaseConnector.sol";

interface IBasisTrading {
    function submitOrder(bytes32 marketKey, uint256 amt, uint256 priceImpactDelta) external;
}

interface IDelegateApprovals {
    function canExchangeFor(address authoriser, address delegate) external view returns (bool);
    function approveExchangeOnBehalf(address delegate) external;
}

interface IAccount {
    function isAuth(address user) external view returns (bool);
    function enable(address user) external;
    function disable(address user) external;
}

contract SynthetixBasisTradingConnector is BaseConnector {
    IBasisTrading public immutable basisTrading;
    IDelegateApprovals public constant delegateApprovals =
        IDelegateApprovals(0x2A23bc0EA97A89abD91214E8e4d20F02Fe14743f);

    string public constant name = "Synthetix-Basis-Trading-v1";

    constructor(IBasisTrading _basisTrading) {
        basisTrading = _basisTrading;
    }

    function submitBasisTradingOrder(bytes32 marketKey, uint256 amt, uint256 priceImpactDelta)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        bool isAuth = IAccount(address(this)).isAuth(address(basisTrading));

        if (!isAuth) {
            IAccount(address(this)).enable(address(basisTrading));
        }

        bool canExchange = delegateApprovals.canExchangeFor(address(this), address(basisTrading));

        if (!canExchange) {
            delegateApprovals.approveExchangeOnBehalf(address(basisTrading));
        }

        basisTrading.submitOrder(marketKey, amt, priceImpactDelta);

        _eventName = "LogSubmitLimitOrder(bytes32,uint256,uint256)";
        _eventParam = abi.encode(marketKey, amt, priceImpactDelta);
    }

    event LogSubmit(bytes32 indexed marketKey, uint256 amt, uint256 priceImpactDelta);
}
