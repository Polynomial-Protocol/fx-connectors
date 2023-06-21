// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {BaseConnector} from "../utils/BaseConnector.sol";

interface ISynthetix {
    function synths(bytes32 currencyKey) external view returns (ERC20);

    function exchangeWithTracking(
        bytes32 sourceCurrencyKey,
        uint256 sourceAmount,
        bytes32 destinationCurrencyKey,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint256 amountReceived);
}

contract SynthetixSpotConnector is BaseConnector {
    string public constant name = "Synthetix-Spot-v1";

    // op mainnet
    ISynthetix public constant synthetix = ISynthetix(0x8700dAec35aF8Ff88c16BdF0418774CB3D7599B4);

    // op goerli
    // ISynthetix public constant synthetix =
    //     ISynthetix(0x2E5ED97596a8368EB9E44B1f3F25B2E813845303);

    function swap(bytes32 from, bytes32 to, uint256 amt, uint256 getId, uint256 setId)
        public
        payable
        returns (string memory _eventName, bytes memory _eventParam)
    {
        uint256 _amt = getUint(getId, amt);

        if (_amt == type(uint256).max) {
            ERC20 fromSynth = synthetix.synths(from);
            _amt = fromSynth.balanceOf(address(this));
        }

        uint256 received =
            synthetix.exchangeWithTracking(from, _amt, to, 0x7cb6bF3e7395965b2162A7C2e6876720C20012d6, "polynomial");

        setUint(setId, received);

        _eventName = "LogSwap(bytes32,bytes32,uint256,uint256,uint256)";
        _eventParam = abi.encode(from, to, _amt, getId, setId);
    }

    event LogSwap(bytes32 indexed from, bytes32 indexed to, uint256 amt, uint256 getId, uint256 setId);
}
