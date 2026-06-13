// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDuxCallee {
    /**
     * @notice Called by a DuxPair contract to execute a swap
     * @param sender Address of the sender
     * @param amount0Out Amount of token0 to output
     * @param amount1Out Amount of token1 to output
     * @param data Additional data
     */
    function duxCall(address sender, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}
