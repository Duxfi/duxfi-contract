// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDuxRouter
 * @notice Interface for the DuxRouter periphery contract that provides liquidity management and swap functionality
 * @dev This interface defines all external functions available for interaction with the DuxRouter contract
 */
interface IDuxRouter {
    /*//////////////////////////////////////////////////////////////
                           LIQUIDITY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add liquidity to a pair by depositing tokens
     * @dev Deposits tokens and mints LP tokens in exchange for them
     * @param tokenA Address of the first token in the pair
     * @param amountA Amount of tokenA to deposit
     * @param tokenB Address of the second token in the pair
     * @param amountB Amount of tokenB to deposit
     * @return actualAmount0 Actual amount of token0 deposited
     * @return actualAmount1 Actual amount of token1 deposited
     * @return lpToken Amount of LP tokens minted for the deposited liquidity
     */
    function addLiquidity(address tokenA, uint256 amountA, address tokenB, uint256 amountB)
        external
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpToken);

    /**
     * @notice Remove liquidity from a pair by burning LP tokens
     * @dev Burns LP tokens and returns underlying tokens to the specified recipient
     * @param tokenA Address of the first token in the pair
     * @param tokenB Address of the second token in the pair
     * @param lpToken Amount of LP tokens to burn
     * @param to Recipient address for the returned tokens
     * @return amount0 Amount of token0 returned to the recipient
     * @return amount1 Amount of token1 returned to the recipient
     */
    function removeLiquidity(address tokenA, address tokenB, uint256 lpToken, address to)
        external
        returns (uint256 amount0, uint256 amount1);

    /*//////////////////////////////////////////////////////////////
                               SWAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Swap exact input tokens for output tokens with multi-hop support
     * @dev Supports multi-hop swaps through intermediate tokens (e.g., USDT -> ETH -> DUX)
     * @dev Transfers exact input amount, ensures minimum output amount
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMin Minimum acceptable amount of output tokens
     * @param paths Array of token addresses defining the swap path (path[0] = input token)
     * @param to Recipient address for the output tokens
     * @param deadline Unix timestamp after which the transaction is invalid
     * @return amounts Array of token amounts for each hop in the path
     * @return pairs Array of pair contract addresses used for each swap hop
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata paths,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts, address[] memory pairs);

    /*//////////////////////////////////////////////////////////////
                           PRICE ORACLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculate the current cumulative prices for a pair
     * @dev Returns the current cumulative price values updated to the current block
     * @param pair Address of the DuxPair contract
     * @return price0Cumulative Current cumulative price of token0 (token1/token0)
     * @return price1Cumulative Current cumulative price of token1 (token0/token1)
     * @return blockTimestamp Current block timestamp
     */
    function currentCumulativePrices(address pair)
        external
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp);

    /**
     * @notice Get the last stored cumulative prices for a pair
     * @dev Returns the cumulative prices as stored in the pair's state (may not be current block)
     * @param pair Address of the DuxPair contract
     * @return price0Cumulative Last stored cumulative price of token0 (token1/token0)
     * @return price1Cumulative Last stored cumulative price of token1 (token0/token1)
     * @return blockTimestamp Last stored block timestamp
     */
    function getLastCumulativePrices(address pair)
        external
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp);
}
