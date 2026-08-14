// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/Test.sol";
import {DuxPair} from "@dex/core/DuxPair.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";

/**
 * @title DuxPairAdminTest
 * @notice Unit tests for DuxPair admin functionality
 */
contract DuxPairAdminTest is BaseFixture, LiquidityFixture {
    function setUp() public override {
        BaseFixture.setUp();
    }
    /* ==============================
      Test Initialize
       ============================== */

    function testInitialize_NotFactory() public {
        vm.startPrank(factory);
        DuxPair newPair = new DuxPair();
        console.log("  New pair address:", address(newPair));
        vm.stopPrank();

        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("DuxPair_FactoryOnly()"));
        newPair.initialize(usdc, weth, SWAP_FEE_BPS);
    }

    function testInitialize_FactorySuccess() public view {
        DuxPair pair = DuxPair(pairUsdcWeth);
        assertEq(pair.token0(), usdc < weth ? usdc : weth, "token0 should be the lower address");
        assertEq(pair.token1(), usdc < weth ? weth : usdc, "token1 should be the higher address");

        assertEq(pair.swapFeeBps(), SWAP_FEE_BPS);
    }

    /* ==============================
      Test Pause Functionality
       ============================== */
    function testPause_Success() public {
        vm.startPrank(factory);
        DuxPair(pairUsdcWeth).pause();
        vm.stopPrank();

        assertTrue(DuxPair(pairUsdcWeth).paused());
    }

    function testPause_NotAuthorized() public {
        vm.startPrank(USER1);
        vm.expectRevert(abi.encodeWithSignature("DuxPair_FactoryOnly()"));
        DuxPair(pairUsdcWeth).pause();
        vm.stopPrank();
    }

    function testPause_WhenAlreadyPaused() public {
        vm.startPrank(factory);
        DuxPair(pairUsdcWeth).pause();
        // Should not revert when already paused
        assertTrue(DuxPair(pairUsdcWeth).paused());

        vm.stopPrank();
    }

    /* ==============================
      Test Unpause Functionality
       ============================== */
    function testUnPause_Success() public {
        vm.startPrank(factory);
        DuxPair(pairUsdcWeth).pause();
        DuxPair(pairUsdcWeth).unpause();
        vm.stopPrank();

        assertFalse(DuxPair(pairUsdcWeth).paused());
    }

    function testUnPause_NotAuthorized() public {
        vm.startPrank(USER1);
        vm.expectRevert(abi.encodeWithSignature("DuxPair_FactoryOnly()"));
        DuxPair(pairUsdcWeth).unpause();
        vm.stopPrank();
    }

    function testUnPause_WhenNotPaused() public {
        vm.startPrank(factory);
        DuxPair(pairUsdcWeth).pause();
        // Should not revert when not paused
        DuxPair(pairUsdcWeth).unpause();
        assertFalse(DuxPair(pairUsdcWeth).paused());

        vm.stopPrank();
    }

    /* ==============================
      Test Paused State Effects
       ============================== */
    function testOperationsWhenPaused() public {
        DuxPair pair = DuxPair(pairUsdcWeth);
        // Setup pool with liquidity
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, 1000 * 10 ** 6, 1 ether);
        pair.mintLpToken(USER1);
        vm.stopPrank();

        // Pause the contract
        vm.prank(factory);
        pair.pause();

        //  Test mint when paused
        vm.startPrank(USER2);
        mintToAndTransferToContract(USER2, pairUsdcWeth, usdc, weth, 100 * 10 ** 6, 0.1 ether);
        vm.expectRevert("Pausable: paused");
        pair.mintLpToken(USER2);
        vm.stopPrank();

        // Test swap when paused
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, 100 * 10 ** 6, 0.1 ether);
        vm.expectRevert("Pausable: paused");
        pair.swap(0, 0, USER1, new bytes(0));

        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, 100 * 10 ** 6, 0.1 ether);
        vm.expectRevert("Pausable: paused");
        pair.burnLpToken(USER1);
        vm.stopPrank();
    }

    /* ========== v"Pausable: paused"With Fee
       ============================== */
    function testGetReservesWithFee_ReturnsCorrectValues() public {
        DuxPair pair = DuxPair(pairUsdcWeth);
        // Setup pool with liquidity
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, 1000 * 10 ** 6, 1 ether);
        pair.mintLpToken(USER1);
        vm.stopPrank();

        (uint256 reserve0, uint256 reserve1, uint16 feeBps) = pair.getReservesWithFee();
        // (,, uint256 expectedReserve0, uint256 expectedReserve1) =
        //     getTokensAndReservesInOrder(pairUsdcWeth, usdc, weth);

        (,,,, uint256 expectedReserve0, uint256 expectedReserve1) =
            getTokensAndReservesInOrder(pairUsdcWeth, usdc, 1000 * 10 ** 6, weth, 1 ether);
        assertEq(reserve0, uint256(expectedReserve0));
        assertEq(reserve1, uint256(expectedReserve1));
        assertEq(feeBps, SWAP_FEE_BPS);
    }

    /* ==============================
      Test Get Cumulative Prices
       ============================== */
    function testGetCumulativePrices_InitialValues() public view {
        DuxPair pair = DuxPair(pairUsdcWeth);
        (uint256 price0Cumulative, uint256 price1Cumulative,) = pair.getCumulativePrices();

        assertEq(price0Cumulative, 0);
        assertEq(price1Cumulative, 0);
    }

    function testGetCumulativePrices_AfterMint() public {
        DuxPair pair = DuxPair(pairUsdcWeth);
        vm.startPrank(USER1);
        mintToAndTransferToContract(USER1, pairUsdcWeth, usdc, weth, 1000 * 10 ** 6, 1 ether);
        pair.mintLpToken(USER1);
        vm.stopPrank();

        // Skip some blocks to allow accumulation
        vm.roll(block.number + 10);

        (uint256 newPrice0Cumulative, uint256 newPrice1Cumulative,) = pair.getCumulativePrices();

        // Should still be 0 since no swaps have occurred
        assertEq(newPrice0Cumulative, 0);
        assertEq(newPrice1Cumulative, 0);
    }
}
