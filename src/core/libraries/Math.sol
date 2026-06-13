// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library Math {
    /**
     * @notice Returns the smaller of two uint256 values.
     * @param a First value.
     * @param b Second value.
     * @return The smaller value.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Babylonian method for computing the square root of a uint256.
     * @param y The number to compute the square root of.
     * @return z The square root.
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y == 0) return 0;

        uint256 x = (y >> 1) + 1;
        z = y;

        unchecked {
            while (x < z) {
                z = x;
                x = (y / x + x) >> 1;
            }
        }
    }
}
