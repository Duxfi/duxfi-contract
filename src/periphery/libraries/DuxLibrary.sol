// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IDuxPair} from "../../core/interfaces/IDuxPair.sol";
import {IDuxFactory} from "../../core/interfaces/IDuxFactory.sol";

library DuxLibrary {
    error DuxLibrary_PairNotExist(address tokenA, address tokenB);

    /**
     * @notice Sort two token addresses deterministically
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return token0 Lower address
     * @return token1 Higher address
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @notice Get reserves of a DuxPair contract with fee
     * @param factory DuxFactory contract address
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return reserveA Reserve of tokenA
     * @return reserveB Reserve of tokenB
     * @return feeBps Swap fee basis points
     * @return pair DuxPair contract address
     */
    function getPairsReservesAndFee(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB, uint16 feeBps, address pair)
    {
        pair = getPairRevertByNotExistPair(factory, tokenA, tokenB);
        (uint256 _r0, uint256 _r1, uint16 _fee) = IDuxPair(pair).getReservesWithFee();
        (reserveA, reserveB, feeBps) = tokenA < tokenB ? (_r0, _r1, _fee) : (_r1, _r0, _fee);
    }

    /**
     * @notice Get DuxPair contract address
     * @param factory DuxFactory contract address
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return pair DuxPair contract address
     */
    function getPairRevertByNotExistPair(address factory, address tokenA, address tokenB)
        internal
        view
        returns (address pair)
    {
        pair = IDuxFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) revert DuxLibrary_PairNotExist(tokenA, tokenB);
    }
}
