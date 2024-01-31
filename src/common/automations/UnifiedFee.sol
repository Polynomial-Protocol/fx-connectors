// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Auth, Authority} from "solmate/auth/Auth.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface IList {
    function accountID(address) external view returns (uint64);
}

interface IOVMGasOracle {
    function DECIMALS() external pure returns (uint256);
    function getL1Fee(bytes memory _data) external view returns (uint256);
    function gasPrice() external view returns (uint256);
    function baseFee() external view returns (uint256);
    function overhead() external view returns (uint256);
    function scalar() external view returns (uint256);
    function l1BaseFee() external view returns (uint256);
    function decimals() external pure returns (uint256);
    function getL1GasUsed(bytes memory _data) external view returns (uint256);
}

interface IChainLink {
    function latestAnswer() external view returns (int256);
}

contract UnifiedFee is Auth, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /// -----------------------------------------------------------------------
    /// Data Types
    /// -----------------------------------------------------------------------

    struct Cost {
        uint128 gasUnitsL1;
        uint128 gasUnitsL2;
    }

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    /// @notice Gas Oracle
    IOVMGasOracle public constant gasOracle = IOVMGasOracle(0x420000000000000000000000000000000000000F);

    /// @notice USDC
    ERC20 public immutable usdc;

    /// @notice SCW Index List
    IList public immutable list;

    /// @notice Chainlink ETH Oracle
    IChainLink public immutable chainLink;

    /// @notice Pending amount to withdraw from contract
    uint256 public pendingAmount;

    /// @notice Deposited balances
    mapping(address => int256) public depositedBalances;

    /// @notice Action costs
    mapping(bytes32 => Cost) public costs;

    constructor(address _usdc, address _list, address _chainLink) Auth(msg.sender, Authority(address(0x0))) {
        usdc = ERC20(_usdc);
        list = IList(_list);
        chainLink = IChainLink(_chainLink);
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function deposit(uint256 amt) external onlyScw {
        usdc.safeTransferFrom(msg.sender, address(this), amt);

        int256 newBalance = depositedBalances[msg.sender] + int256(amt);

        depositedBalances[msg.sender] = newBalance;
    }

    function claim(bytes32[] memory _actions) external onlyScw {
        uint256 totalL1Units;
        uint256 totalL2Units;

        for (uint256 i = 0; i < _actions.length; i++) {
            Cost memory cost = costs[_actions[i]];

            totalL1Units += cost.gasUnitsL1;
            totalL2Units += cost.gasUnitsL2;
        }

        uint256 gasPriceL2 = gasOracle.gasPrice();
        uint256 overhead = gasOracle.overhead();
        uint256 l1BaseFee = gasOracle.l1BaseFee();
        uint256 decimals = gasOracle.decimals();
        uint256 scalar = gasOracle.scalar();

        uint256 costOfExecutionGrossEth =
            ((((totalL1Units + overhead) * l1BaseFee * scalar) / 10 ** decimals) + (totalL2Units * gasPriceL2));

        int256 ethPrice = chainLink.latestAnswer();

        uint256 ethPriceWad = uint256(ethPrice) * (10 ** 10);

        uint256 totalCost = ethPriceWad.mulWadDown(costOfExecutionGrossEth);

        depositedBalances[msg.sender] -= int256(totalCost);
        pendingAmount += totalCost;
    }

    /// -----------------------------------------------------------------------
    /// Admin Actions
    /// -----------------------------------------------------------------------

    function setCosts(bytes32[] memory _actions, Cost[] memory _costs) external requiresAuth {
        require(_actions.length == _costs.length);

        for (uint256 i = 0; i < _actions.length; i++) {
            costs[_actions[i]] = _costs[i];
        }
    }

    function sweep(address to) external requiresAuth {
        usdc.safeTransfer(to, pendingAmount);
        pendingAmount = 0;
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyScw() {
        if (list.accountID(msg.sender) == 0) {
            revert NotScw(msg.sender);
        }
        _;
    }

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    /**
     * @notice Not Smart wallet error
     * @param user Address of the requested user
     */
    error NotScw(address user);
}
