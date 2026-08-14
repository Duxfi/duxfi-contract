// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {DuxPair} from "@dex/core/DuxPair.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {EventFixture} from "../shared/fixtures/EventFixture.sol";

/**
 * @title DuxPairBurnTest
 * @notice Unit tests for DuxPair burn functionality
 */
contract DuxPairBurnTest is BaseFixture, LiquidityFixture, EventFixture {
    DuxPair pair;

    function setUp() public override {
        BaseFixture.setUp();
        pair = DuxPair(pairUsdcWeth);
    }

    /* ==============================
      Test Burn LPToken - Success Cases
       ============================== */
    function testBurnLpToken_Success() public {
        mintPoolUsdcWeth();
        address _user = USER1;
        vm.startPrank(_user);
        LiquidityState memory stateBefore = captureState(_user, pairUsdcWeth, usdc, weth);

        uint256 lpAmountToRemove = stateBefore.lpBalance;
        bool success = pair.transfer(pairUsdcWeth, lpAmountToRemove);
        assertTrue(success, "Transfer failed");

        (uint256 amount0, uint256 amount1) = pair.burnLpToken(_user);
        LiquidityState memory stateAfter = captureState(_user, pairUsdcWeth, usdc, weth);

        uint256 actualUsdcOut;
        uint256 actualWethOut;
        if (pair.token0() == usdc) {
            actualUsdcOut = amount0;
            actualWethOut = amount1;
        } else {
            actualUsdcOut = amount1;
            actualWethOut = amount0;
        }

        uint256 expectedUsdcOut =
            getExpectedAmountAfterBurn(lpAmountToRemove, stateBefore.reserveA, stateBefore.totalSupply);
        uint256 expectedWethOut =
            getExpectedAmountAfterBurn(lpAmountToRemove, stateBefore.reserveB, stateBefore.totalSupply);

        assertEq(actualUsdcOut, expectedUsdcOut, "USDC amount out should be correct");
        assertEq(actualWethOut, expectedWethOut, "WETH amount out should be correct");
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance - lpAmountToRemove, "LP balance should decrease");
        assertEq(stateAfter.userBalanceA, stateBefore.userBalanceA + actualUsdcOut, "USDC balance should increase");
        assertEq(stateAfter.userBalanceB, stateBefore.userBalanceB + actualWethOut, "WETH balance should increase");
        assertEq(stateAfter.reserveA, stateBefore.reserveA - actualUsdcOut, "USDC reserve should decrease");
        assertEq(stateAfter.reserveB, stateBefore.reserveB - actualWethOut, "WETH reserve should decrease");
        assertEq(stateAfter.totalSupply, stateBefore.totalSupply - lpAmountToRemove, "Total supply should decrease");

        vm.stopPrank();
    }

    /* ==============================
      Test Burn LPToken - Events
       ============================== */
    function testBurnLpToken_EmitEvent() public {
        mintPoolUsdcWeth();
        address user = USER1;
        vm.startPrank(user);
        uint256 lpTokens = pair.balanceOf(user);
        bool success = pair.transfer(pairUsdcWeth, lpTokens);
        assertTrue(success, "Transfer failed");
        (uint256 expectedAmount0, uint256 expectedAmount1) = getExpectedAmountsAfterBurn(lpTokens, pairUsdcWeth);
        expectLiquidityRemovedEvent(pairUsdcWeth, user, expectedAmount0, expectedAmount1, lpTokens, user);
        (uint256 amount0, uint256 amount1) = pair.burnLpToken(user);
        vm.stopPrank();
        assertEq(amount0, expectedAmount0);
        assertEq(amount1, expectedAmount1);
    }

    /* ==============================
      Test Burn LPToken - Edge Cases
       ============================== */
    function testBurnLpToken_EmptyPoolReverts() public {
        vm.startPrank(USER1);
        vm.expectRevert(abi.encodeWithSignature("DuxPair_TotalSupplyIsZero()"));
        pair.burnLpToken(USER1);
        vm.stopPrank();
    }

    function testBurnLpToken_ZeroAmountReverts() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);
        bool success = pair.transfer(pairUsdcWeth, 0);
        assertTrue(success, "Transfer failed");
        (uint256 amount0, uint256 amount1) = pair.burnLpToken(USER1);
        assertEq(amount0, 0);
        assertEq(amount1, 0);
        vm.stopPrank();
    }

    function testBurnLpToken_InsufficientBalance() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);
        uint256 lpTokens = pair.balanceOf(USER1);
        bool success = pair.transfer(pairUsdcWeth, lpTokens / 2);
        assertTrue(success, "Transfer failed");

        (uint256 amount0, uint256 amount1) = pair.burnLpToken(USER1);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(pair.balanceOf(USER1), lpTokens - (lpTokens / 2));

        vm.stopPrank();
    }

    /* ==============================
      Test Burn LPToken - Gas & Security
       ============================== */
    function testBurnLpToken_GasUsage() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);

        uint256 lpTokens = pair.balanceOf(USER1);
        bool success = pair.transfer(pairUsdcWeth, lpTokens);
        assertTrue(success, "Transfer failed");

        uint256 gasBefore = gasleft();
        (uint256 amount0, uint256 amount1) = pair.burnLpToken(USER1);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for burnLpToken:", gasUsed);
        console.log("USDC received:", amount0);
        console.log("WETH received:", amount1);

        assertLt(gasUsed, 150000);
        assertGt(amount0, 0);
        assertGt(amount1, 0);

        vm.stopPrank();
    }

    function testBurnLpToken_ReentrancyProtection() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);
        uint256 lpTokens = pair.balanceOf(USER1);
        bool success = pair.transfer(pairUsdcWeth, lpTokens);
        assertTrue(success, "Transfer failed");

        (uint256 amount0, uint256 amount1) = pair.burnLpToken(USER1);
        assertGt(amount0, 0);
        assertGt(amount1, 0);

        vm.stopPrank();
    }
}
