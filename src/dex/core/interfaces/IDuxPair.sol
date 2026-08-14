// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDuxPair
 * @notice Interface for DuxPair AMM liquidity pool
 * @dev This interface defines the standard functions for interacting with DEX liquidity pairs
 */
interface IDuxPair {
    /// @notice First token of the pair (sorted by address)
    function token0() external view returns (address);

    /// @notice Second token of the pair (sorted by address)
    function token1() external view returns (address);

    /// @notice Swap fee in basis points (e.g., 30 = 0.3%)
    function swapFeeBps() external view returns (uint16);

    /// @notice Cumulative price of token0 (for TWAP calculation)
    /// @dev Note: cumulative prices are public in implementation
    function price0CumulativeLast() external view returns (uint256);

    /// @notice Cumulative price of token1 (for TWAP calculation)
    /// @dev Note: cumulative prices are public in implementation
    function price1CumulativeLast() external view returns (uint256);

    /**
     * @notice Initialize the pair with tokens and fee
     * @param _tokenA Address of first token
     * @param _tokenB Address of second token
     * @param _swapFeeBps Basis points swap fee
     */
    function initialize(address _tokenA, address _tokenB, uint16 _swapFeeBps) external;

    /**
     * @notice Mint LP token for liquidity providers.
     * @param to Recipient address
     * @return liquidity Amount of LP tokens minted
     */
    function mintLpToken(address to) external returns (uint256 liquidity);

    /**
     * @notice Burn LP tokens and receive underlying assets.
     * @param to Recipient address
     * @return amount0 Amount of token0 returned
     * @return amount1 Amount of token1 returned
     */
    function burnLpToken(address to) external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Swap tokens in the pool
     * @param amount0Out Amount of token0 to output
     * @param amount1Out Amount of token1 to output
     * @param to Recipient address
     * @param data Additional data
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /**
     * @notice Get current reserves and last update timestamp
     * @return _reserve0 Current reserve of token0
     * @return _reserve1 Current reserve of token1
     * @return _blockTimestampLast Last block timestamp of reserve update
     */
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast);

    /**
     * @notice Get reserves with swap fee
     * @return _reserve0 Current reserve of token0
     * @return _reserve1 Current reserve of token1
     * @return _fee Current swap fee in basis points
     */
    function getReservesWithFee() external view returns (uint256 _reserve0, uint256 _reserve1, uint16 _fee);
    /**
     * @notice Pause the contract (emergency stop)
     */
    function pause() external;

    /**
     * @notice Unpause the contract (resume operations)
     */
    function unpause() external;

    /**
     * @notice Transfer tokens from one address to another
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param value Amount of tokens to transfer
     * @return success Whether the transfer was successful
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    /**
     * @notice Get the current cumulative prices for a pair
     * @return price0Cumulative The cumulative price of token0
     * @return price1Cumulative The cumulative price of token1
     * @return blockTimestamp The timestamp of the last block
     */
    function getCumulativePrices()
        external
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp);
}
