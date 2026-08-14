// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DuxRouter} from "../../src/periphery/DuxRouter.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {MockERC} from "../mocks/MockERC.sol";
import {DuxPair} from "../../src/core/DuxPair.sol";

/**
 * @title DuxRouterTest
 * @notice Unit tests for DuxRouter contract
 */
contract DuxRouterRemoveLiqTest is BaseFixture, LiquidityFixture {
    DuxRouter router;
    DuxPair pair;

    function setUp() public override {
        BaseFixture.setUp();
        router = new DuxRouter(factory);
        pair = DuxPair(pairUsdcWeth);
    }

    function testRemoveLiquidity_Success() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);

        uint256 lpAmountToRemove = pair.balanceOf(USER1) / 2; // Remove 50% of liquidity

        // state before transaction
        LiquidityState memory stateBefore = captureState(USER1, pairUsdcWeth, usdc, weth);

        // approve router to spend LP tokens
        pair.approve(address(router), lpAmountToRemove);

        // run transaction
        (uint256 actualUsdcOut, uint256 actualWethOut) = router.removeLiquidity(usdc, weth, lpAmountToRemove, USER1);

        // state after transaction
        LiquidityState memory stateAfter = captureState(USER1, pairUsdcWeth, usdc, weth);

        // calculate expected amounts
        uint256 expectedUsdcOut =
            getExpectedAmountAfterBurn(lpAmountToRemove, stateBefore.reserveA, stateBefore.totalSupply);
        uint256 expectedWethOut =
            getExpectedAmountAfterBurn(lpAmountToRemove, stateBefore.reserveB, stateBefore.totalSupply);

        // assertions
        assertEq(actualUsdcOut, expectedUsdcOut, "USDC output should match expected amount based on LP tokens burned");
        assertEq(actualWethOut, expectedWethOut, "WETH output should match expected amount based on LP tokens burned");
        assertEq(
            stateAfter.lpBalance,
            stateBefore.lpBalance - lpAmountToRemove,
            "LP balance should decrease by burned amount"
        );
        assertEq(
            stateAfter.userBalanceA,
            stateBefore.userBalanceA + actualUsdcOut,
            "USDC balance should increase by withdrawn amount"
        );
        assertEq(
            stateAfter.userBalanceB,
            stateBefore.userBalanceB + actualWethOut,
            "WETH balance should increase by withdrawn amount"
        );
        assertEq(
            stateAfter.reserveA,
            stateBefore.reserveA - actualUsdcOut,
            "USDC reserve should decrease by withdrawn amount"
        );
        assertEq(
            stateAfter.reserveB,
            stateBefore.reserveB - actualWethOut,
            "WETH reserve should decrease by withdrawn amount"
        );
        assertEq(
            stateAfter.totalSupply,
            stateBefore.totalSupply - lpAmountToRemove,
            "Total supply should decrease by burned LP tokens"
        );

        vm.stopPrank();
    }

    function testRemoveLiquidity_RemoveAll_Success() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);

        uint256 lpAmountToRemove = pair.balanceOf(USER1); // Remove 100% of liquidity
        // state before transaction
        LiquidityState memory stateBefore = captureState(USER1, pairUsdcWeth, usdc, weth);

        // approve router to spend LP tokens
        pair.approve(address(router), lpAmountToRemove);
        // calculate expected amounts
        uint256 expectedUsdcOut = (lpAmountToRemove * stateBefore.reserveA) / stateBefore.totalSupply;
        uint256 expectedWethOut = (lpAmountToRemove * stateBefore.reserveB) / stateBefore.totalSupply;

        // run transaction
        (uint256 actualUsdcOut, uint256 actualWethOut) = router.removeLiquidity(usdc, weth, lpAmountToRemove, USER1);

        // state after transaction
        LiquidityState memory stateAfter = captureState(USER1, pairUsdcWeth, usdc, weth);

        // assertions
        assertEq(actualUsdcOut, expectedUsdcOut, "USDC output should match expected");
        assertEq(actualWethOut, expectedWethOut, "WETH output should match expected");
        assertEq(stateAfter.lpBalance, 0, "LP balance should be zero after removing all");
        assertEq(stateAfter.totalSupply, stateBefore.lockedLp, "Total supply should be zero after removing all");
        assertEq(stateAfter.userBalanceA, stateBefore.userBalanceA + actualUsdcOut, "USDC balance should increase");
        assertEq(stateAfter.userBalanceB, stateBefore.userBalanceB + actualWethOut, "WETH balance should increase");

        // Calculate minimum liquidity reserves based on 1000 LP tokens
        uint256 minReserveA = (stateBefore.lockedLp * stateBefore.reserveA) / stateBefore.totalSupply;
        uint256 minReserveB = (stateBefore.lockedLp * stateBefore.reserveB) / stateBefore.totalSupply;

        assertApproxEqAbs(stateAfter.reserveA, minReserveA, 1);
        assertApproxEqAbs(stateAfter.reserveB, minReserveB, 1);

        vm.stopPrank();
    }

    function testRemoveLiquidity_ZeroLpToken_Reverts() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);

        vm.expectRevert();
        router.removeLiquidity(usdc, weth, 0, USER1);
        vm.stopPrank();
    }

    function testRemoveLiquidity_ZeroAddressA_Reverts() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);
        uint256 lpAmountToRemove = pair.balanceOf(USER1) / 2;
        pair.approve(address(router), lpAmountToRemove);
        vm.expectRevert();
        router.removeLiquidity(address(0), weth, lpAmountToRemove, USER1);
        vm.stopPrank();
    }

    function testRemoveLiquidity_ZeroAddressB_Reverts() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);
        uint256 lpAmountToRemove = pair.balanceOf(USER1) / 2;
        pair.approve(address(router), lpAmountToRemove);
        vm.expectRevert();
        router.removeLiquidity(usdc, address(0), lpAmountToRemove, USER1);
        vm.stopPrank();
    }

    function testRemoveLiquidity_SameToken_Reverts() public {
        vm.startPrank(USER1);
        uint256 lpAmountToRemove = pair.balanceOf(USER1);
        pair.approve(address(router), lpAmountToRemove);
        vm.expectRevert();
        router.removeLiquidity(usdc, usdc, lpAmountToRemove, USER1);
        vm.stopPrank();
    }

    function testRemoveLiquidity_NotApproved_Reverts() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);

        uint256 lpAmountToRemove = pair.balanceOf(USER1) / 2;

        vm.expectRevert("ERC20: insufficient allowance");
        router.removeLiquidity(usdc, weth, lpAmountToRemove, USER1);
        vm.stopPrank();
    }

    function testRemoveLiquidity_UnknownToken_Reverts() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);

        uint256 lpAmountToRemove = pair.balanceOf(USER1) / 2;
        pair.approve(address(router), lpAmountToRemove);

        MockERC unknownToken = new MockERC("Unknown", "UNK", 18);

        vm.expectRevert();
        router.removeLiquidity(usdc, address(unknownToken), lpAmountToRemove, USER1);
        vm.stopPrank();
    }
}
