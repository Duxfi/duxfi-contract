// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title FixedPoint
 * @notice Library for handling binary fixed-point numbers (Q112.112 format).
 * @dev Range [0, 2**112 − 1], resolution 1 / 2**112.
 */
library FixedPoint {
    uint224 constant Q112 = 2 ** 112;
    // forge-lint: disable-next-line
    struct uq112x112 {
        uint224 _x;
    }

    /**
     * @notice Encodes a uint112 as a UQ112x112 fixed-point number.
     * @param y The uint112 value to encode.
     * @return z The UQ112x112 encoded value.
     */
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    /**
     * @notice Divides a UQ112x112 by a uint112, returning a UQ112x112.
     * @param x The UQ112x112 numerator.
     * @param y The uint112 denominator.
     * @return z The UQ112x112 result.
     */
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }

    /**
     * @notice Decodes a UQ112x112 into a uint112 with loss of precision.
     * @param x The UQ112x112 value.
     * @return z The decoded uint112.
     */
    function decode(uint224 x) internal pure returns (uint112 z) {
         // casting to 'uint112' is safe because x/Q112 result is guaranteed to fit in uint112
         // forge-lint: disable-next-line(unsafe-typecast)
        z = uint112(x / Q112);
    }

    /**
     * @notice Multiplies two UQ112x112 numbers.
     * @param x First UQ112x112 operand.
     * @param y Second UQ112x112 operand.
     * @return z The UQ112x112 product.
     */
    function mul(uint224 x, uint224 y) internal pure returns (uint224 z) {
        z = (x * y) / Q112;
    }

    /**
     * @notice Divides two UQ112x112 numbers.
     * @param x The UQ112x112 numerator.
     * @param y The UQ112x112 denominator.
     * @return z The UQ112x112 quotient.
     */
    function div(uint224 x, uint224 y) internal pure returns (uint224 z) {
        z = (x * Q112) / y;
    }

    /**
     * @notice Returns a UQ112x112 representing the ratio numerator / denominator.
     * @param numerator The numerator as uint112.
     * @param denominator The denominator as uint112.
     * @return result The UQ112x112 ratio.
     */
    function fraction(uint256 numerator, uint256 denominator) internal pure returns (uq112x112 memory result) {
        require(denominator > 0, "FixedPoint::fraction: division by zero");
        if (numerator == 0) return uq112x112({ _x: 0 });

        uint256 r = (numerator << 112) / denominator;
        require(r <= type(uint224).max, "FixedPoint::fraction: overflow");
        // casting to 'uint224' is safe because we've checked that r <= type(uint224).max
        // forge-lint: disable-next-line(unsafe-typecast)
        result = uq112x112({ _x: uint224(r) });
    }
}
