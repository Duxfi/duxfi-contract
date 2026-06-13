// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IDuxPair} from "../../core/interfaces/IDuxPair.sol";
import {FixedPoint} from "../../libraries/FixedPoint.sol";

library DuxTWAPOracleLibrary {
    using FixedPoint for *;

    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    /**
     * @dev calculate the TWAP price of the pair
     * @param pair   DuxPair address
     * @return price0Cumulative  price0CumulativeLast
     * @return price1Cumulative  price1CumulativeLast
     * @return blockTimestamp  blockTimestampLast
     */
    function currentCumulativePrices(address pair)
        internal
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IDuxPair(pair).price0CumulativeLast();
        price1Cumulative = IDuxPair(pair).price1CumulativeLast();

        (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast) = IDuxPair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            if (reserve0 == 0 || reserve1 == 0) {
                return (price0Cumulative, price1Cumulative, blockTimestamp);
            }
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            price0Cumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
            price1Cumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }
}
