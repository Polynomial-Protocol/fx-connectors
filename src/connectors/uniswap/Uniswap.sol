// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {BaseConnector} from "../../utils/BaseConnector.sol";
import {ISwapRouter, IQuoterV2, IWETH} from "./interfaces.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract UniswapV3Connector is BaseConnector {
    using SafeTransferLib for ERC20;

    string public constant name = "uniswap-v3-v1";
    address internal constant uniswapRouter =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address internal constant uniswapQuoterV2 =
        0x61fFE014bA17989E743c5F6cB21bF9697530B21e;

    function resolveFees(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) public returns (uint24, uint256) {
        // fees
        /**
         * try all these and fetch lowest amount in
         * 0.01% * 10^6 = 100
         * 0.05% * 10^6 = 500
         * 0.3% * 10^6 = 3000
         * 1% * 10^6 = 10000
         * */
        IQuoterV2 swapQuoterV2 = IQuoterV2(uniswapQuoterV2);
        uint24[4] memory feesArr = [
            uint24(100),
            uint24(500),
            uint24(3000),
            uint24(10000)
        ];

        uint24 feesForLowestAmountInIndex = 0;
        uint256 lowestAmountIn = FixedPointMathLib.MAX_UINT256;
        for (uint24 i = 0; i < feesArr.length; i++) {
            uint24 fee = feesArr[i];
            IQuoterV2.QuoteExactOutputSingleParams memory params = IQuoterV2
                .QuoteExactOutputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amount: amountOut,
                    fee: fee,
                    sqrtPriceLimitX96: 0
                });
            (uint256 amountIn, , , ) = swapQuoterV2.quoteExactOutputSingle(
                params
            );
            if (lowestAmountIn > amountIn) {
                lowestAmountIn = amountIn;
                feesForLowestAmountInIndex = i;
            }
        }

        return (feesArr[feesForLowestAmountInIndex], lowestAmountIn);
    }

    /**
     * @notice Swap tokens
     * @dev Sell ETH/ERC20_token using uniswap
     * @param from The address of the token to buy.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param to The address of the token to sell.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param minToReceive Min. Amount of tokens to receive after swapping
     */
    function swap(
        address from,
        address to,
        uint256 amtInMaximum,
        uint256 minToReceive
    ) external payable {
        uint256 msgValue;
        ERC20 toToken = ERC20(to);
        uint256 initialBal = to == ethAddr
            ? address(this).balance
            : toToken.balanceOf(address(this));

        if (from == ethAddr) {
            msgValue = amtInMaximum;
            IWETH(wethAddr).deposit{value: amtInMaximum}();
        } else {
            ERC20(from).safeApprove(uniswapRouter, amtInMaximum);
        }

        address tokenIn = from == ethAddr ? wethAddr : from;
        address tokenOut = to == ethAddr ? wethAddr : to;

        (uint24 fee, ) = resolveFees(tokenIn, tokenOut, minToReceive);
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee, // need to fetch this fee from a resolver
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: minToReceive,
                amountInMaximum: amtInMaximum,
                sqrtPriceLimitX96: 0
            });

        ISwapRouter swapRouter = ISwapRouter(uniswapRouter);

        swapRouter.exactOutputSingle(params);

        uint256 finalBal = to == ethAddr
            ? address(this).balance
            : toToken.balanceOf(address(this));
        uint256 received = finalBal - initialBal;
        require(received >= minToReceive, "did-not-receive-minimum");

        emit LogSwap(from, to, amtInMaximum, minToReceive);
    }

    event LogSwap(
        address indexed from,
        address indexed to,
        uint256 amt,
        uint256 minReceived
    );
}
