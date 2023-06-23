// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Initializable} from "../proxy/utils/Initializable.sol";
import {AuthUpgradable, Authority} from "../libraries/AuthUpgradable.sol";

interface AddressResolver {
    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}

interface GasPriceOracle {
    function gasPrice() external view returns (uint256);

    function l1BaseFee() external view returns (uint256);

    function overhead() external view returns (uint256);

    function scalar() external view returns (uint256);

    function decimals() external view returns (uint256);

    function getL1Fee(bytes memory _data) external view returns (uint256);

    function getL1GasUsed(bytes memory _data) external view returns (uint256);
}

interface ExchangeRates {
    function rateAndInvalid(bytes32 currencyKey) external view returns (uint256 rate, bool isInvalid);
}

contract GasEstimater is Initializable, AuthUpgradable {
    GasPriceOracle public constant GAS_PRICE_ORACLE = GasPriceOracle(0x420000000000000000000000000000000000000F);
    AddressResolver public constant SNX_RESOLVER = AddressResolver(0x95A6a3f44a70172E7d50a9e28c85Dfd712756B8C);

    uint256 private _minKeeperFeeUpperBound;
    uint256 private _minKeeperFeeLowerBound;
    uint256 private _gasUnitsL1;
    uint256 private _gasUnitsL2;

    function initialize(
        address _owner,
        uint256 minKeeperFeeUpperBound,
        uint256 minKeeperFeeLowerBound,
        uint256 gasUnitsL1,
        uint256 gasUnitsL2
    ) public initializer {
        _auth_init(_owner, Authority(address(0x0)));

        _minKeeperFeeLowerBound = minKeeperFeeLowerBound;
        _minKeeperFeeUpperBound = minKeeperFeeUpperBound;
        _gasUnitsL1 = gasUnitsL1;
        _gasUnitsL2 = gasUnitsL2;
    }

    function getKeeperFee() public view returns (uint256) {
        ExchangeRates exchangeRates =
            ExchangeRates(SNX_RESOLVER.requireAndGetAddress("ExchangeRates", "Missing ExchangeRates address"));

        (uint256 price, bool invalid) = exchangeRates.rateAndInvalid("ETH");
        require(!invalid, "Invalid price");

        uint256 gasPriceL2 = GAS_PRICE_ORACLE.gasPrice();
        uint256 overhead = GAS_PRICE_ORACLE.overhead();
        uint256 l1BaseFee = GAS_PRICE_ORACLE.l1BaseFee();
        uint256 decimals = GAS_PRICE_ORACLE.decimals();
        uint256 scalar = GAS_PRICE_ORACLE.scalar();

        uint256 costOfExecutionGrossEth =
            ((((_gasUnitsL1 + overhead) * l1BaseFee * scalar) / 10 ** decimals) + (_gasUnitsL2 * gasPriceL2));
        uint256 costOfExecutionGross = costOfExecutionGrossEth * price / 1e18;

        return min(_minKeeperFeeUpperBound, max(_minKeeperFeeLowerBound, costOfExecutionGross));
    }

    function setParameters(
        uint256 minKeeperFeeUpperBound,
        uint256 minKeeperFeeLowerBound,
        uint256 gasUnitsL1,
        uint256 gasUnitsL2
    ) external requiresAuth {
        _minKeeperFeeUpperBound = minKeeperFeeUpperBound;
        _minKeeperFeeLowerBound = minKeeperFeeLowerBound;
        _gasUnitsL1 = gasUnitsL1;
        _gasUnitsL2 = gasUnitsL2;
    }

    function getParameters()
        external
        view
        returns (uint256 minKeeperFeeUpperBound, uint256 minKeeperFeeLowerBound, uint256 gasUnitsL1, uint256 gasUnitsL2)
    {
        minKeeperFeeUpperBound = _minKeeperFeeUpperBound;
        minKeeperFeeLowerBound = _minKeeperFeeLowerBound;
        gasUnitsL1 = _gasUnitsL1;
        gasUnitsL2 = _gasUnitsL2;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
