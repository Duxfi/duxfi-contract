// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DuxPair} from "../../src/core/DuxPair.sol";

library SwapLib {
    uint256 constant SWAP_FEE_BPS = 30;
    uint256 constant FEE_DENOMINATOR = 10000;

    /**
     * @notice Calculate expected output amount for a swap
     * @param _pair Swap pair contract
     * @param amountIn Input token amount
     * @param _amountInToken Input token contract
     * @return amount0Out Expected output amount for token0
     * @return amount1Out Expected output amount for token1
     * @return expectedOutput Expected output amount for the target token
     */
    function getExpectedSwapOutput(address _pair, uint256 amountIn, address _amountInToken)
        public
        view
        returns (
            uint256 amount0Out,
            uint256 amount1Out,
            uint256 expectedOutput,
            uint256 fee,
            uint256 amount0In,
            uint256 amount1In
        )
    {
        require(amountIn > 0, "Insufficient input amount");
        DuxPair pair = DuxPair(_pair);
        (uint256 reserve0, uint256 reserve1,) = DuxPair(_pair).getReserves();

        // Ensure reserves are sufficient
        require(reserve0 > 0 && reserve1 > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - SWAP_FEE_BPS);
        fee = amountIn * SWAP_FEE_BPS / FEE_DENOMINATOR;

        if (_amountInToken == pair.token0()) {
            // Input is token0, output is token1
            amount0Out = 0;
            amount1Out = (amountInWithFee * reserve1) / (reserve0 * FEE_DENOMINATOR + amountInWithFee);
            expectedOutput = amount1Out;
            amount0In = amountIn;
            amount1In = 0;
        } else {
            // Input is token1, output is token0
            amount0Out = (amountInWithFee * reserve0) / (reserve1 * FEE_DENOMINATOR + amountInWithFee);
            amount1Out = 0;
            expectedOutput = amount0Out;
            amount0In = 0;
            amount1In = amountIn;
        }
    }

    /**
     * @notice Calculate expected output amount for multiple token swaps, make sure pairs and tokens in the right orders
     * @param swapIn Input token amount
     * @param pairs Swap pair contracts
     * @param tokens Token contracts
     * @return expectedOuts Expected output amount for the last token
     */
    function getExpectedOutPutForPairs(uint256 swapIn, address[] memory pairs, address[] memory tokens)
        public
        view
        returns (uint256[] memory expectedOuts)
    {
        uint256 amountIn = swapIn;
        expectedOuts = new uint256[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            (,, uint256 expectedOut,,,) = getExpectedSwapOutput(pairs[i], amountIn, tokens[i]);
            amountIn = expectedOut;
            expectedOuts[i] = expectedOut;
        }
        return expectedOuts;
    }
}
