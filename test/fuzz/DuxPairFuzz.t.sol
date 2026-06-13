// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DuxPair} from "../../src/core/DuxPair.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {SwapLib} from "../utils/SwapLib.sol";

/**
 * @title DuxPairFuzzTest
 * @notice Fuzz tests for DuxPair contract
 * @dev Comprehensive fuzz testing suite for core AMM functionality
 */
contract DuxPairFuzzTest is BaseFixture, LiquidityFixture {
    DuxPair pair;
    address user;

    function setUp() public override {
        BaseFixture.setUp();
        pair = DuxPair(pairUsdcWeth);
        user = USER1;
    }

    function _setupEmptyPool(address _user) internal returns (uint256 lpTokens) {
        vm.startPrank(_user);
        mintToAndTransferToContract(_user, pairUsdcWeth, usdc, weth, AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);
        lpTokens = pair.mintLpToken(_user);
        vm.stopPrank();
    }

    function testFuzz_mintLpToken(uint256 amount0, uint256 amount1, bool isNewPoll) public {
        // Bound inputs to avoid trivial/overflow cases
        amount0 = bound(amount0, 1e6, 1e25);
        amount1 = bound(amount1, 1e6, 1e25);

        if (!isNewPoll) {
            _setupEmptyPool(USER2);
        }
        vm.startPrank(user);
        LiquidityState memory stateBefore;
        if (isNewPoll) {
            mintToAndTransferToContract(user, address(pair), usdc, weth, amount0, amount1);
            stateBefore = captureState(user, pairUsdcWeth, usdc, weth);
        } else {
            mintAndApproveToContract(user, address(pair), usdc, weth, amount0, amount1);
            stateBefore = captureState(user, pairUsdcWeth, usdc, weth);
            transferToContract(user, address(pair), usdc, weth, amount0, amount1);
        }
        uint256 lpTokens = pair.mintLpToken(user);
        uint256 userBalance = pair.balanceOf(user);
        vm.stopPrank();

        LiquidityState memory stateAfter = captureState(user, pairUsdcWeth, usdc, weth);
        assertGt(lpTokens, 0, "LP tokens should be minted");
        assertEq(userBalance, lpTokens, "User should receive LP tokens");
        assertEq(stateAfter.reserveA, stateBefore.reserveA + amount0, "Reserve A should increase by deposited amount");
        assertEq(stateAfter.reserveB, stateBefore.reserveB + amount1, "Reserve B should increase by deposited amount");
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance + lpTokens, "LP balance should increase by minted amount");
        assertEq(stateAfter.userBalanceA, 0, "User should have no remaining token A");
        assertEq(stateAfter.userBalanceB, 0, "User should have no remaining token B");
    }

    function testFuzz_Swap(uint256 amountIn) public {
        _setupEmptyPool(user);
        // Skip test if parameters are outside safe range
        amountIn = bound(amountIn, 1e6, 1e25);
        address _user = USER2;

        vm.startPrank(_user);
        mintAndApproveToContract(_user, pairUsdcWeth, usdc, weth, amountIn, 0);

        LiquidityState memory stateBefore = captureState(_user, pairUsdcWeth, usdc, weth);
        transferToContract(_user, pairUsdcWeth, usdc, weth, amountIn, 0);

        (uint256 amount0Out, uint256 amount1Out, uint256 expectedOut, uint256 fee,,) =
            SwapLib.getExpectedSwapOutput(pairUsdcWeth, amountIn, usdc);

        pair.swap(amount0Out, amount1Out, _user, "");

        LiquidityState memory stateAfter = captureState(_user, pairUsdcWeth, usdc, weth);
        vm.stopPrank();

        assertGt(expectedOut, 0, "Should get some output");
        assertEq(fee, amountIn * SWAP_FEE_BPS / feeDenominator, "Fee calculation should be correct");
        assertEq(stateAfter.userBalanceA, stateBefore.userBalanceA - amountIn);
        assertEq(stateAfter.userBalanceB, stateBefore.userBalanceB + expectedOut);
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance);
        assertEq(stateAfter.totalSupply, stateBefore.totalSupply);
        assertEq(stateAfter.reserveA, stateBefore.reserveA + amountIn);
        assertEq(stateAfter.reserveB, stateBefore.reserveB - expectedOut);
    }

    function testFuzz_BurnLPToken(uint256 lpAmountToBurn, bool isPartialBurn) public {
        // First, setup the pool and mint some LP tokens
        _setupEmptyPool(user);

        vm.startPrank(user);
        uint256 totalLpBalance = pair.balanceOf(user);

        // Bound lpAmountToBurn to be valid
        if (isPartialBurn) {
            // For partial burn, burn between 1% and 99% of LP tokens
            lpAmountToBurn = bound(lpAmountToBurn, totalLpBalance / 100, totalLpBalance - (totalLpBalance / 100));
        } else {
            // For full burn, burn all LP tokens
            lpAmountToBurn = totalLpBalance;
        }

        // Capture state before burn
        LiquidityState memory stateBefore = captureState(user, pairUsdcWeth, usdc, weth);

        // Transfer LP tokens to the pair contract
        bool success = pair.transfer(pairUsdcWeth, lpAmountToBurn);
        assertTrue(success, "Transfer failed");

        // Burn LP tokens
        (uint256 amount0, uint256 amount1) = pair.burnLpToken(user);

        // Capture state after burn
        LiquidityState memory stateAfter = captureState(user, pairUsdcWeth, usdc, weth);
        vm.stopPrank();

        // Determine which amount corresponds to which token
        uint256 actualUsdcOut;
        uint256 actualWethOut;
        if (pair.token0() == usdc) {
            actualUsdcOut = amount0;
            actualWethOut = amount1;
        } else {
            actualUsdcOut = amount1;
            actualWethOut = amount0;
        }

        // Calculate expected amounts
        uint256 expectedUsdcOut =
            getExpectedAmountAfterBurn(lpAmountToBurn, stateBefore.reserveA, stateBefore.totalSupply);
        uint256 expectedWethOut =
            getExpectedAmountAfterBurn(lpAmountToBurn, stateBefore.reserveB, stateBefore.totalSupply);

        // Verify burn was successful
        assertGt(actualUsdcOut, 0, "Should receive USDC");
        assertGt(actualWethOut, 0, "Should receive WETH");
        assertEq(actualUsdcOut, expectedUsdcOut, "USDC amount out should be correct");
        assertEq(actualWethOut, expectedWethOut, "WETH amount out should be correct");

        // Verify state changes
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance - lpAmountToBurn, "LP balance should decrease");
        assertEq(stateAfter.userBalanceA, stateBefore.userBalanceA + actualUsdcOut, "USDC balance should increase");
        assertEq(stateAfter.userBalanceB, stateBefore.userBalanceB + actualWethOut, "WETH balance should increase");
        assertEq(stateAfter.reserveA, stateBefore.reserveA - actualUsdcOut, "USDC reserve should decrease");
        assertEq(stateAfter.reserveB, stateBefore.reserveB - actualWethOut, "WETH reserve should decrease");
        assertEq(stateAfter.totalSupply, stateBefore.totalSupply - lpAmountToBurn, "Total supply should decrease");
    }
}
