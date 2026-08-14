// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DuxPair} from "../../src/core/DuxPair.sol";
import {RouterFixture} from "../shared/fixtures/RouterFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {SwapLib} from "../utils/SwapLib.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {MockERC} from "../mocks/MockERC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DuxRouterFuzzTest
 * @notice Fuzz tests for DuxRouter contract
 * @dev Comprehensive fuzz testing suite for core router functionality
 */
contract DuxRouterFuzzTest is RouterFixture, LiquidityFixture {
    function setUp() public override(RouterFixture, BaseFixture) {
        RouterFixture.setUp();
    }

    function testFuzz_AddLiquidity_EmptyPool(uint256 amount0, uint256 amount1) public {
        // Bound inputs to avoid trivial/overflow cases
        amount0 = bound(amount0, 1e6, 1e25);
        amount1 = bound(amount1, 1e6, 1e25);
        mintAndApproveToContract(USER1, address(router), usdc, weth, amount0, amount1);
        vm.startPrank(USER1);
        LiquidityState memory stateBefore = captureState(USER1, pairUsdcWeth, usdc, weth);
        (uint256 actualAmountUsdc, uint256 actualAmountWeth, uint256 lpToken) =
            router.addLiquidity(usdc, amount0, weth, amount1);
        LiquidityState memory stateAfter = captureState(USER1, pairUsdcWeth, usdc, weth);
        uint256 iniExpectedToken = getLpTokenForEmptyPool(amount0, amount1);

        assertEq(actualAmountUsdc, amount0, "USDC deposit amount should match expected initial deposit");
        assertEq(actualAmountWeth, amount1, "WETH deposit amount should match expected initial deposit");
        assertEq(lpToken, iniExpectedToken, "LP tokens minted should match calculated expected amount");
        assertEq(
            DuxPair(pairUsdcWeth).balanceOf(USER1), iniExpectedToken, "User LP token balance should equal minted amount"
        );
        assertEq(MockERC(usdc).balanceOf(USER1), 0, "User USDC balance should be zero after deposit");
        assertEq(MockERC(weth).balanceOf(USER1), 0, "User WETH balance should be zero after deposit");
        assertEq(
            stateAfter.reserveA,
            stateBefore.reserveA + actualAmountUsdc,
            "USDC reserve should increase by deposited amount"
        );
        assertEq(
            stateAfter.reserveB,
            stateBefore.reserveB + actualAmountWeth,
            "WETH reserve should increase by deposited amount"
        );

        vm.stopPrank();
    }

    function testFuzz_AddLiquidity_ExistingPool(uint256 amount0, uint256 amount1) public {
        // Skip the test if inputs are outside safe range to prevent zero deposit
        amount0 = bound(amount0, 1e6, 1e25);
        amount1 = bound(amount1, 1e6, 1e25);

        mintPoolUsdcWeth();
        address user = USER1;
        // set up transaction
        mintAndApproveToContract(user, address(router), usdc, weth, amount0, amount1);
        vm.startPrank(user);
        // captured state before transaction
        LiquidityState memory stateBefore = captureState(user, pairUsdcWeth, usdc, weth);
        try router.addLiquidity(usdc, amount0, weth, amount1) returns (
            uint256 actualAmountUsdc, uint256 actualAmountWeth, uint256 lpToken
        ) {
            if (actualAmountUsdc == amount0) {
                assertGt(amount1, actualAmountWeth);
            } else {
                assertGt(amount0, actualAmountUsdc);
            }
            uint256 expectedLp = getLpTokenForExistingPool(
                actualAmountUsdc, actualAmountWeth, stateBefore.totalSupply, stateBefore.reserveA, stateBefore.reserveB
            );
            assertEq(lpToken, expectedLp, "LP tokens minted should match calculated expected amount for existing pool");
            LiquidityState memory stateAfter = captureState(user, pairUsdcWeth, usdc, weth);
            assertEq(stateAfter.reserveA, stateBefore.reserveA + actualAmountUsdc, "reserveA should be updated");
            assertEq(stateAfter.reserveB, stateBefore.reserveB + actualAmountWeth, "reserveB should be updated");
            assertEq(stateAfter.lpBalance, stateBefore.lpBalance + lpToken, "lpBalance should be updated");
            assertEq(
                stateAfter.userBalanceA, stateBefore.userBalanceA - actualAmountUsdc, "userBalanceA should be updated"
            );
            assertEq(
                stateAfter.userBalanceB, stateBefore.userBalanceB - actualAmountWeth, "userBalanceB should be updated"
            );
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("Invalid desired amounts ratio"))) {
                emit log("Caught Invalid desired amounts ratio, skipping this fuzz case");
                emit log_uint(amount0);
                emit log_uint(amount1);
                vm.stopPrank();
                return;
            } else {
                revert(reason); // other reason return fail
            }
        } catch (bytes memory lowLevelData) {
            // captuer error and revert
            assembly {
                revert(add(lowLevelData, 0), mload(lowLevelData))
            }
        }
        vm.stopPrank();
    }

    function testFuzz_RemoveLiquidity(uint256 initialAmount0, uint256 initialAmount1, uint256 removeLpAmount) public {
        // Bound inputs to avoid trivial/overflow cases
        initialAmount0 = bound(initialAmount0, 1e6, 1e25);
        initialAmount1 = bound(initialAmount1, 1e6, 1e25);

        // Setup initial pool with liquidity
        mintAndApproveToContract(USER1, address(router), usdc, weth, initialAmount0, initialAmount1);
        vm.startPrank(USER1);

        // Add initial liquidity to create pool and get LP tokens
        router.addLiquidity(usdc, initialAmount0, weth, initialAmount1);

        // Get user's LP token balance after adding liquidity
        uint256 userLpBalance = DuxPair(pairUsdcWeth).balanceOf(USER1);

        // Bound removeLpAmount to be within user's available LP tokens and greater than 0
        removeLpAmount = bound(removeLpAmount, 1, userLpBalance);

        // Approve router to spend LP tokens for removal
        DuxPair(pairUsdcWeth).approve(address(router), removeLpAmount);

        // Capture state before removing liquidity
        LiquidityState memory stateBefore = captureState(USER1, pairUsdcWeth, usdc, weth);

        try router.removeLiquidity(usdc, weth, removeLpAmount, USER1) returns (
            uint256 amountTokenUsdc, uint256 amountTokenWeth
        ) {
            // Capture state after removing liquidity
            LiquidityState memory stateAfter = captureState(USER1, pairUsdcWeth, usdc, weth);

            // Calculate expected amounts based on proportional share
            uint256 expectedAmountUsdc = (removeLpAmount * stateBefore.reserveA) / stateBefore.totalSupply;
            uint256 expectedAmountWeth = (removeLpAmount * stateBefore.reserveB) / stateBefore.totalSupply;

            // Verify returned amounts match expected proportional share
            assertEq(amountTokenUsdc, expectedAmountUsdc, "Returned USDC amount should match proportional share");
            assertEq(amountTokenWeth, expectedAmountWeth, "Returned WETH amount should match proportional share");

            // Verify user's LP balance decreased by removed amount
            assertEq(
                stateAfter.lpBalance,
                stateBefore.lpBalance - removeLpAmount,
                "LP balance should decrease by removed amount"
            );

            // Verify user's token balances increased by returned amounts
            assertEq(
                stateAfter.userBalanceA,
                stateBefore.userBalanceA + amountTokenUsdc,
                "User USDC balance should increase by returned amount"
            );
            assertEq(
                stateAfter.userBalanceB,
                stateBefore.userBalanceB + amountTokenWeth,
                "User WETH balance should increase by returned amount"
            );

            // Verify pool reserves decreased by returned amounts
            assertEq(
                stateAfter.reserveA,
                stateBefore.reserveA - amountTokenUsdc,
                "Pool USDC reserve should decrease by returned amount"
            );
            assertEq(
                stateAfter.reserveB,
                stateBefore.reserveB - amountTokenWeth,
                "Pool WETH reserve should decrease by returned amount"
            );

            // Verify total supply decreased by removed amount
            assertEq(
                stateAfter.totalSupply,
                stateBefore.totalSupply - removeLpAmount,
                "Total supply should decrease by removed amount"
            );
        } catch Error(string memory reason) {
            // Handle string revert cases
            if (keccak256(bytes(reason)) == keccak256(bytes("DuxRouter_InsufficientLiquidityAmount"))) {
                emit log("Caught InsufficientLiquidityAmount, skipping this fuzz case");
                emit log_uint(removeLpAmount);
                emit log_uint(stateBefore.totalSupply);
            } else if (keccak256(bytes(reason)) == keccak256(bytes("DuxRouter_ZeroAddress"))) {
                emit log("Caught ZeroAddress, skipping this fuzz case");
            } else {
                emit log("Unexpected revert reason:");
                emit log_string(reason);
                revert(reason);
            }
        } catch (bytes memory lowLevelData) {
            // Capture low-level errors and revert
            emit log("Caught low-level error");
            assembly {
                revert(add(lowLevelData, 0), mload(lowLevelData))
            }
        }
        vm.stopPrank();
    }

    function testFuzz_SwapExactTokensForTokens(uint256 swapAmountIn, uint256 userExpectedMinOut) public {
        // Bound inputs to avoid trivial/overflow cases
        swapAmountIn = bound(swapAmountIn, 1e6, 1e25);
        userExpectedMinOut = bound(userExpectedMinOut, 1e6, 1e25);

        // Setup environment
        mintPoolAll();
        mintAndApproveToContract(USER1, address(router), usdc, weth, swapAmountIn, 0);

        // Get paths and expected outputs
        address[] memory paths = getPathsFromUsdcToDai();
        address[] memory pairs = getPairsFromUsdcToDai();
        uint256[] memory expectedOuts = SwapLib.getExpectedOutPutForPairs(swapAmountIn, pairs, paths);

        // Determine if we expect a revert
        if (userExpectedMinOut > expectedOuts[expectedOuts.length - 1]) {
            // Expect a revert with specific error message
            vm.expectRevert("DuxRouter_DoesNotMeetUserExpectedMinOut()");
            vm.prank(USER1);
            router.swapExactTokensForTokens(swapAmountIn, userExpectedMinOut, paths, USER2, block.timestamp);
            emit log("Expected revert with DuxRouter_DoesNotMeetUserExpectedMinOut() happened as expected");
        } else {
            // Get balances and state before swap
            uint256 receiverBalanceBefore = IERC20(dai).balanceOf(USER2);
            uint256 senderBalanceBefore = IERC20(usdc).balanceOf(USER1);
            LiquidityState memory stateUsdcBefore = captureState(USER1, pairUsdcWeth, usdc, weth);
            LiquidityState memory stateDaiBefore = captureState(USER2, pairBtcDai, btc, dai);

            // Execute swap without expecting revert
            vm.startPrank(USER1);
            (uint256[] memory amounts,) =
                router.swapExactTokensForTokens(swapAmountIn, userExpectedMinOut, paths, USER2, block.timestamp);
            vm.stopPrank();

            // Get balances and state after swap
            LiquidityState memory stateUsdcAfter = captureState(USER1, pairUsdcWeth, usdc, weth);
            LiquidityState memory stateDaiAfter = captureState(USER2, pairBtcDai, btc, dai);

            // Verify swap results
            // Ensure user's expected minimum output is not greater than actual output
            assertLe(
                userExpectedMinOut,
                amounts[paths.length - 1],
                "userExpectedMinOut should be <= actual output when swap succeeds"
            );

            // Verify all assertions for successful swap
            for (uint256 i = 0; i < pairs.length; i++) {
                assertEq(amounts[i + 1], expectedOuts[i], "amounts[i+1] should be equal to expectedOuts[i]");
            }
            assertEq(IERC20(dai).balanceOf(USER2), receiverBalanceBefore + amounts[paths.length - 1], "daiBalanceAfter");
            assertEq(IERC20(usdc).balanceOf(USER1), senderBalanceBefore - swapAmountIn, "usdcBalanceAfter");
            assertEq(stateUsdcAfter.reserveA, stateUsdcBefore.reserveA + swapAmountIn, "reserveA");
            assertEq(stateUsdcAfter.reserveB, stateUsdcBefore.reserveB - amounts[1], "reserveB");
            assertEq(stateDaiAfter.reserveA, stateDaiBefore.reserveA + amounts[paths.length - 2], "reserveA");
            assertEq(stateDaiAfter.reserveB, stateDaiBefore.reserveB - amounts[paths.length - 1], "reserveB");
        }
    }
}
