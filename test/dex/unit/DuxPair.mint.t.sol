// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/Test.sol";
import {DuxPair} from "@dex/core/DuxPair.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {EventFixture} from "../shared/fixtures/EventFixture.sol";

/**
 * @title DuxPairMintTest
 * @notice Unit tests for DuxPair mint functionality
 */
contract DuxPairMintTest is BaseFixture, LiquidityFixture, EventFixture {
    DuxPair pair;

    function setUp() public override {
        BaseFixture.setUp();
        pair = DuxPair(pairUsdcWeth);
    }

    function _setupEmptyPool(address user) internal returns (uint256 lpTokens) {
        vm.startPrank(user);
        mintToAndTransferToContract(user, pairUsdcWeth, usdc, weth, AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);
        lpTokens = pair.mintLpToken(user);
        vm.stopPrank();
    }
    /* ==============================
      Test Mint LPToken - Empty Pool
       ============================== */

    function testmintLpToken_EmptyPool() public {
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);
        LiquidityState memory stateBefore = captureState(USER1, pairUsdcWeth, usdc, weth);

        uint256 lpTokens = pair.mintLpToken(USER1);
        uint256 userBalance = pair.balanceOf(USER1);

        LiquidityState memory stateAfter = captureState(USER1, pairUsdcWeth, usdc, weth);

        vm.stopPrank();
        assertGt(lpTokens, 0);
        assertEq(userBalance, lpTokens);
        assertEq(stateAfter.reserveA, stateBefore.reserveA + AMOUNT_INIT_USDC);
        assertEq(stateAfter.reserveB, stateBefore.reserveB + AMOUNT_INIT_WETH);
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance + lpTokens);
        assertEq(stateAfter.userBalanceA, 0);
        assertEq(stateAfter.userBalanceB, 0);
    }

    /* ==============================
      Test Mint LPToken - Existing Pool
       ============================== */
    function testmintLpToken_ExistingPool_USER2() public {
        _setupEmptyPool(USER2);
        address user = USER2;
        vm.startPrank(user);
        mintAndApproveToContract(user, pairUsdcWeth, usdc, weth, AMOUNT_ADDLIQ_USDC, AMOUNT_ADDLIQ_WETH);
        LiquidityState memory stateBefore = captureState(user, pairUsdcWeth, usdc, weth);
        transferToContract(user, pairUsdcWeth, usdc, weth, AMOUNT_ADDLIQ_USDC, AMOUNT_ADDLIQ_WETH);
        uint256 lpTokens = pair.mintLpToken(user);
        vm.stopPrank();

        assertGt(lpTokens, 0);
        assertEq(pair.totalSupply(), stateBefore.totalSupply + lpTokens);

        LiquidityState memory stateAfter = captureState(user, pairUsdcWeth, usdc, weth);

        assertEq(stateAfter.reserveA, stateBefore.reserveA + AMOUNT_ADDLIQ_USDC);
        assertEq(stateAfter.reserveB, stateBefore.reserveB + AMOUNT_ADDLIQ_WETH);
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance + lpTokens);
        assertEq(stateAfter.userBalanceA, stateBefore.userBalanceA - AMOUNT_ADDLIQ_USDC);
        assertEq(stateAfter.userBalanceB, stateBefore.userBalanceB - AMOUNT_ADDLIQ_WETH);
    }

    /* ==============================
      Test Mint LPToken - Imbalanced
       ============================== */
    function testmintLpToken_ImbalancedAddLiquidity() public {
        address user = USER2;
        _setupEmptyPool(user);
        vm.startPrank(user);
        uint256 amount0 = 1000 * 10 ** 6; // 1000 USDC
        uint256 amount1 = 2 ether; // 2 WETH (wrong ratio)
        mintAndApproveToContract(user, pairUsdcWeth, usdc, weth, amount0, amount1);

        LiquidityState memory stateBefore = captureState(user, pairUsdcWeth, usdc, weth);
        transferToContract(user, pairUsdcWeth, usdc, weth, amount0, amount1);

        uint256 lpTokens = pair.mintLpToken(user);
        uint256 expectedLp = getLpTokenForExistingPool(
            amount0, amount1, stateBefore.totalSupply, stateBefore.reserveA, stateBefore.reserveB
        );

        assertEq(lpTokens, expectedLp, "lpTokens");
        LiquidityState memory stateAfter = captureState(user, pairUsdcWeth, usdc, weth);

        assertEq(stateAfter.reserveA, stateBefore.reserveA + amount0, "reserveA");
        assertEq(stateAfter.reserveB, stateBefore.reserveB + amount1, "reserveB");
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance + lpTokens, "lpBalance");
        assertEq(stateAfter.userBalanceA, stateBefore.userBalanceA - amount0, "userBalanceA");
        assertEq(stateAfter.userBalanceB, stateBefore.userBalanceB - amount1, "userBalanceB");
        vm.stopPrank();
    }

    /* ==============================
      Test Mint LPToken - Edge Cases
       ============================== */
    function testmintLpToken_EmptyPoolSyc() public {
        _setupEmptyPool(USER1);
        (address token0,,,, uint256 reserve0, uint256 reserve1) =
            getTokensAndReservesInOrder(pairUsdcWeth, usdc, AMOUNT_INIT_USDC, weth, AMOUNT_INIT_WETH);
        if (token0 == usdc) {
            assertEq(reserve0, AMOUNT_INIT_USDC, "1 reserve0");
            assertEq(reserve1, AMOUNT_INIT_WETH, "1 reserve1");
        } else {
            assertEq(reserve0, AMOUNT_INIT_WETH, "2 reserve0");
            assertEq(reserve1, AMOUNT_INIT_USDC, "2 reserve1");
        }
    }

    function testmintLpToken_ExistingPoolSyc() public {
        testmintLpToken_ExistingPool_USER2();
        (address token0,,,, uint256 reserve0, uint256 reserve1) =
            getTokensAndReservesInOrder(pairUsdcWeth, usdc, AMOUNT_INIT_USDC, weth, AMOUNT_INIT_WETH);

        if (token0 == usdc) {
            assertEq(uint256(reserve0), AMOUNT_INIT_USDC + AMOUNT_ADDLIQ_USDC);
            assertEq(uint256(reserve1), AMOUNT_INIT_WETH + AMOUNT_ADDLIQ_WETH);
        } else {
            assertEq(uint256(reserve0), AMOUNT_INIT_WETH + AMOUNT_ADDLIQ_WETH);
            assertEq(uint256(reserve1), AMOUNT_INIT_USDC + AMOUNT_ADDLIQ_USDC);
        }
    }

    /* ==============================
      Test Mint LPToken - Events
      ============================== */
    function testmintLpToken_EmitEvent() public {
        address user = USER1;
        vm.startPrank(user);
        mintToAndTransferToContract(user, pairUsdcWeth, usdc, weth, AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);

        (, uint256 amount0,, uint256 amount1, uint256 reserve0Before, uint256 reserve1Before) =
            getTokensAndReservesInOrder(pairUsdcWeth, usdc, AMOUNT_INIT_USDC, weth, AMOUNT_INIT_WETH);
        uint256 expectedReserve0 = reserve0Before + amount0;
        uint256 expectedReserve1 = reserve1Before + amount1;
        uint256 expectedLpTokens = getLpTokenForEmptyPool(AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);

        expectSyncEvent(pairUsdcWeth, expectedReserve0, expectedReserve1, expectedLpTokens, uint32(block.timestamp));

        expectLiquidityAddedEvent(pairUsdcWeth, user, amount0, amount1, expectedLpTokens);

        uint256 actualLpTokens = pair.mintLpToken(user);

        assertEq(actualLpTokens, expectedLpTokens, "LP tokens should match expected");
        vm.stopPrank();
    }

    /* ==============================
      Test Mint LPToken - Reverts
       ============================== */
    function testmintLpToken_InsufficientLiquidityAmount_EmptyPool() public {
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, AMOUNT_TOO_SMALL_USDC, AMOUNT_TOO_SMALL_WETH);
        vm.expectRevert();
        pair.mintLpToken(USER1);
        vm.stopPrank();
    }

    function testmintLpToken_InsufficientLiquidityAmount_ExistingPool() public {
        _setupEmptyPool(USER1);
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, AMOUNT_TOO_SMALL_USDC, AMOUNT_TOO_SMALL_WETH);

        vm.expectRevert(abi.encodeWithSignature("DuxPair_LpTokenIsZero()"));
        pair.mintLpToken(USER1);
        vm.stopPrank();
    }

    function testmintLpToken_ZeroAmountReverts() public {
        _setupEmptyPool(USER2);
        vm.startPrank(USER2);
        mintToAndTransferToContract(USER2, pairUsdcWeth, usdc, weth, 0, 0);
        vm.expectRevert(abi.encodeWithSignature("DuxPair_LpTokenIsZero()"));
        pair.mintLpToken(USER2);
        vm.stopPrank();
    }

    function testmintLpToken_SingleTokenReverts() public {
        _setupEmptyPool(USER2);
        vm.startPrank(USER2);
        mintToAndTransferToContract(USER2, pairUsdcWeth, usdc, weth, 1, 0);
        vm.expectRevert(abi.encodeWithSignature("DuxPair_LpTokenIsZero()"));
        pair.mintLpToken(USER2);
        vm.stopPrank();

        vm.startPrank(USER2);
        mintToAndTransferToContract(USER2, pairUsdcWeth, usdc, weth, 0, 1);
        vm.expectRevert(abi.encodeWithSignature("DuxPair_LpTokenIsZero()"));
        pair.mintLpToken(USER2);
        vm.stopPrank();
    }

    function testmintLpToken_GasOptimization() public {
        vm.startPrank(USER2);
        mintToAndTransferToContract(USER2, pairUsdcWeth, usdc, weth, 1000 * 10 ** 6, 0.5 ether);
        uint256 gasBefore = gasleft();
        uint256 lpTokens = pair.mintLpToken(USER2);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for mintLpToken:", gasUsed);
        console.log("LP tokens minted:", lpTokens);
        assertLt(gasUsed, 200000);
        assertGt(lpTokens, 0);
        vm.stopPrank();
    }
}
