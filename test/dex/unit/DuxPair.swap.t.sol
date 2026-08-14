// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/Test.sol";
import {DuxPair} from "@dex/core/DuxPair.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {EventFixture} from "../shared/fixtures/EventFixture.sol";
import {MockERC} from "../mocks/MockERC.sol";
import {SwapLib} from "../utils/SwapLib.sol";

/**
 * @title DuxPairSwapTest
 * @notice Unit tests for DuxPair swap functionality
 * @dev Comprehensive test suite covering basic swaps, edge cases, events, and gas optimization
 */
contract DuxPairSwapTest is BaseFixture, LiquidityFixture, EventFixture {
    DuxPair pair;
    /// @dev Test constants for standardized swap amounts
    uint256 private constant SWAP_AMOUNT_USDC = 1000 * 10 ** 6; // 1000 USDC
    uint256 private constant SWAP_AMOUNT_WETH = 1 ether; // 1 WETH
    uint256 private constant MIN_OUTPUT_THRESHOLD = 0.4 ether; // Minimum expected output
    uint256 private constant MAX_GAS_LIMIT = 150_000; // Maximum gas usage threshold

    function setUp() public override {
        BaseFixture.setUp();
        pair = DuxPair(pairUsdcWeth);
    }

    /* ==============================
       Internal Helpers
       ============================== */

    /// @dev Setup pool with initial liquidity
    function _setupPool() internal {
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);
        pair.mintLpToken(USER1);
        vm.stopPrank();
    }

    /* ==============================
      Test Swap - Basic Functionality
       ============================== */
    function testSwap_Success() public {
        _setupPool();
        address _user = USER2;

        vm.startPrank(_user);
        uint256 amountIn = SWAP_AMOUNT_USDC; // 1000 USDC
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

    function testSwap_ExactInput() public {
        _setupPool();
        vm.startPrank(USER1);

        uint256 amountIn = SWAP_AMOUNT_USDC;
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, amountIn, 0);

        uint256 balanceBefore = MockERC(weth).balanceOf(USER1);
        (uint256 amount0Out, uint256 amount1Out, uint256 expectedOut, uint256 fee,,) =
            SwapLib.getExpectedSwapOutput(pairUsdcWeth, amountIn, usdc);

        pair.swap(amount0Out, amount1Out, USER1, "");

        uint256 balanceAfter = MockERC(weth).balanceOf(USER1);
        uint256 actualOut = balanceAfter - balanceBefore;

        assertGt(actualOut, 0);
        assertEq(actualOut, expectedOut);
        assertEq(fee, amountIn * SWAP_FEE_BPS / feeDenominator);
        vm.stopPrank();
    }

    /* ==============================
      Test Swap - Edge Cases
       ============================== */
    function testSwap_InsufficientLiquidity() public {
        _setupPool();
        uint256 amountIn = AMOUNT_INIT_USDC + SWAP_AMOUNT_USDC; // 1M USDC (much larger than pool)

        (uint256 amount0Out, uint256 amount1Out,,,,) = SwapLib.getExpectedSwapOutput(pairUsdcWeth, amountIn, usdc);
        console.log("amount0Out:", amount0Out);
        console.log("amount1Out:", amount1Out);

        vm.startPrank(USER1);
        vm.expectRevert();
        pair.swap(amount0Out, amount1Out, USER1, "");
        vm.stopPrank();
    }

    function testSwap_ZeroInputReverts() public {
        _setupPool();
        vm.startPrank(USER1);
        vm.expectRevert();
        pair.swap(0, 0, USER1, "");
        vm.stopPrank();
    }

    /* ==============================
      Test Swap - Events
       ============================== */
    function testSwap_EmitSwapEvent() public {
        _setupPool();
        uint256 amountIn = SWAP_AMOUNT_USDC;
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, amountIn, 0);
        vm.startPrank(USER1);
        (uint256 amount0Out, uint256 amount1Out,,, uint256 amount0In, uint256 amount1In) =
            SwapLib.getExpectedSwapOutput(pairUsdcWeth, amountIn, usdc);
        (uint256 reserve0Before, uint256 reserve1Before,) = pair.getReserves();
        expectSyncEvent(pairUsdcWeth, reserve0Before + amount0In - amount0Out, reserve1Before + amount1In - amount1Out, pair.totalSupply(), uint32(block.timestamp));
        expectSwapEvent(pairUsdcWeth, USER1, amount0In, amount1In, amount0Out, amount1Out, USER1);
        pair.swap(amount0Out, amount1Out, USER1, "");
        vm.stopPrank();
    }

    /* ==============================
      Test Swap - Gas & Performance
       ============================== */
    function testSwap_GasUsage() public {
        _setupPool();
        vm.startPrank(USER1);

        uint256 amountIn = SWAP_AMOUNT_USDC;
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, amountIn, 0);
        (uint256 amount0Out, uint256 amount1Out, uint256 expectedOut,,,) =
            SwapLib.getExpectedSwapOutput(pairUsdcWeth, amountIn, usdc);

        uint256 gasBefore = gasleft();
        pair.swap(amount0Out, amount1Out, USER1, "");
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for swap:", gasUsed);
        console.log("USDC input:", amountIn);
        console.log("WETH output:", expectedOut);

        assertLt(gasUsed, 150000); // Should be less than 150k gas

        vm.stopPrank();
    }

    /* ==============================
      Test Swap - Token Directions
       ============================== */
    function testSwap_USDCtoWETH() public {
        _setupPool();
        vm.startPrank(USER1);

        uint256 amountIn = SWAP_AMOUNT_USDC;
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, amountIn, 0);

        uint256 wethBalanceBefore = MockERC(weth).balanceOf(USER1);
        (uint256 amount0Out, uint256 amount1Out,,,,) = SwapLib.getExpectedSwapOutput(pairUsdcWeth, amountIn, usdc);

        pair.swap(amount0Out, amount1Out, USER1, "");

        uint256 wethBalanceAfter = MockERC(weth).balanceOf(USER1);
        assertGt(wethBalanceAfter, wethBalanceBefore);

        vm.stopPrank();
    }

    function testSwap_WETHtoUSDC() public {
        _setupPool();
        vm.startPrank(USER1);

        uint256 amountIn = 1 ether; // 1 WETH
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, 0, amountIn);

        uint256 usdcBalanceBefore = MockERC(usdc).balanceOf(USER1);
        (uint256 amount0Out, uint256 amount1Out,,,,) = SwapLib.getExpectedSwapOutput(pairUsdcWeth, amountIn, weth);

        pair.swap(amount0Out, amount1Out, USER1, "");

        uint256 usdcBalanceAfter = MockERC(usdc).balanceOf(USER1);
        assertGt(usdcBalanceAfter, usdcBalanceBefore);

        vm.stopPrank();
    }
}
