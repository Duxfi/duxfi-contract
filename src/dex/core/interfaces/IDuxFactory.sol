// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDuxFactory {
    /// @notice Maximum swap fee in basis points (1000 = 10%)
    function MAX_SWAP_FEE_BPS() external view returns (uint16);
    /**
     * @notice Get the address of the pair for two tokens
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @return pair Address of the pair contract
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    /**
     * @notice Get the total number of pairs created
     * @return length Number of pairs
     */
    function allPairsLength() external view returns (uint256 length);
    /**
     * @notice Get the address of a pair by index
     * @param index Index of the pair
     * @return pair Address of the pair contract
     */
    function allPairs(uint256 index) external view returns (address pair);
    /**
     * @notice Create a new pair contract
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @param swapFeeBps Swap fee in basis points (0-1000)
     * @param creator Address of the creator
     * @return pair Address of the created pair contract
     */
    function createPair(address tokenA, address tokenB, uint16 swapFeeBps, address creator) external returns (address pair);

    function getPairByTokens(address tokenA, address tokenB) external view returns (address pair);
}
