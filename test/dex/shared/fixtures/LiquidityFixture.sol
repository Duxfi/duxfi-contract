// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseFixture} from "./BaseFixture.sol";
import {console} from "forge-std/console.sol";
import {DuxPair} from "@dex/core/DuxPair.sol";
import {MockERC} from "../../mocks/MockERC.sol";

contract LiquidityFixture is BaseFixture {
    struct LiquidityState {
        uint256 lpBalance;
        uint256 userBalanceA;
        uint256 userBalanceB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        uint256 lockedLp;
    }

    function getLpTokenForEmptyPool(uint256 token0, uint256 token1) public view returns (uint256 lpToken) {
        uint256 k = sqrt(token0 * token1);
        if (k <= minLiquidity) {
            lpToken = k;
        } else {
            lpToken = k - minLiquidity;
        }
    }

    function sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function getLpTokenForExistingPool(
        uint256 deposit0,
        uint256 deposit1,
        uint256 totalSupply,
        uint256 reserve0,
        uint256 reserve1
    ) public pure returns (uint256 lpToken) {
        uint256 amount0 = (deposit0 * totalSupply) / reserve0;
        uint256 amount1 = (deposit1 * totalSupply) / reserve1;
        lpToken = amount0 < amount1 ? amount0 : amount1;
    }

    function captureState(address user, address pairUsdcWeth, address tokenA, address tokenB)
        public
        view
        returns (LiquidityState memory)
    {
        DuxPair _pair = DuxPair(pairUsdcWeth);
        return LiquidityState({
            lpBalance: _pair.balanceOf(user),
            userBalanceA: MockERC(tokenA).balanceOf(user),
            userBalanceB: MockERC(tokenB).balanceOf(user),
            reserveA: getReserveByToken(pairUsdcWeth, tokenA),
            reserveB: getReserveByToken(pairUsdcWeth, tokenB),
            totalSupply: _pair.totalSupply(),
            lockedLp: _pair.MINIMUM_LIQUIDITY()
        });
    }

    function getReserveByToken(address pairUsdcWeth, address token) public view returns (uint256 reserve) {
        DuxPair _pair = DuxPair(pairUsdcWeth);
        (uint256 r0, uint256 r1,) = _pair.getReserves();
        if (token == _pair.token0()) {
            reserve = r0;
        } else if (token == _pair.token1()) {
            reserve = r1;
        }
    }

    function getTokensAndReservesInOrder(
        address _pairUsdcWeth,
        address tokenA,
        uint256 amountA,
        address tokenB,
        uint256 amountB
    )
        public
        view
        returns (address token0, uint256 amount0, address token1, uint256 amount1, uint256 reserve0, uint256 reserve1)
    {
        DuxPair _pair = DuxPair(_pairUsdcWeth);
        if (tokenA == _pair.token0()) {
            token0 = tokenA;
            amount0 = amountA;
            token1 = tokenB;
            amount1 = amountB;
        } else if (tokenA == _pair.token1()) {
            token0 = tokenB;
            amount0 = amountB;
            token1 = tokenA;
            amount1 = amountA;
        } else {
            console.log("unknown tokenA:", tokenA);
        }
        (reserve0, reserve1,) = _pair.getReserves();
    }

    function getExpectedAmountAfterBurn(uint256 _liquidityToBurn, uint256 balanceA, uint256 _totalSupply)
        public
        pure
        returns (uint256 amountA)
    {
        amountA = (_liquidityToBurn * balanceA) / _totalSupply;
    }

    function getExpectedAmountsAfterBurn(uint256 _liquidityToBurn, address pair)
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        DuxPair _pair = DuxPair(pair);
        uint256 balance0 = MockERC(_pair.token0()).balanceOf(pair);
        uint256 balance1 = MockERC(_pair.token1()).balanceOf(pair);
        uint256 _totalSupply = _pair.totalSupply();
        amount0 = (_liquidityToBurn * balance0) / _totalSupply;
        amount1 = (_liquidityToBurn * balance1) / _totalSupply;
    }
}
