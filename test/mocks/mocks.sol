// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IAccount, IList, IPythNode, IPyth, IPerpMarket} from "../../src/automations/SynthetixLimitOrdersV3.sol";

contract MockIAccount is IAccount {
    function cast(string[] calldata _targetNames, bytes[] calldata _datas, address _origin) external {
        // not mocking for now
    }

    function isAuth(address) external pure returns (bool) {
        return true;
    }
}

contract MockIList is IList {
    function accountID(address addr) external pure override returns (uint64) {
        return uint64(uint160(addr));
    }
}

contract MockIPyth is IPyth {
    uint256 public updateFee;

    function setUpdateFee(uint256 fee) external {
        updateFee = fee;
    }

    function getUpdateFee(bytes[] memory) external view override returns (uint256) {
        return updateFee;
    }
}

contract MockIPythNode is IPythNode {
    IPyth public pyth;
    int256 public latestPrice;

    function setLatestPrice(int256 price) external {
        latestPrice = price;
    }

    constructor(IPyth _pyth) {
        pyth = _pyth;
    }

    function pythAddress() external view override returns (IPyth) {
        return pyth;
    }

    function fulfillOracleQuery(bytes memory signedOffchainData) external payable override {
        // not mocking for now
    }

    function getLatestPrice(bytes32, uint256) external view override returns (int256) {
        return latestPrice;
    }
}

contract MockIPerpMarket is IPerpMarket {
    int256 public pnl;
    int256 public accruedFunding;
    int128 public positionSize;

    function getOpenPosition(uint128, uint128) external view returns (int256, int256, int128) {
        return (pnl, accruedFunding, positionSize);
    }
}
