// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/Test.sol";
import {DuxPair} from "../../src/core/DuxPair.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";

/**
 * @title DuxPairTokenTest
 * @notice Unit tests for DuxPair token functionality
 */
contract DuxPairTokenTest is BaseFixture, LiquidityFixture {
    string constant NAME = "Dux LP Token";
    string constant SYMBOL = "DUX-LP";
    DuxPair pair;

    function setUp() public override {
        BaseFixture.setUp();
        pair = DuxPair(pairUsdcWeth);
    }

    /* ==============================
      Test Initial State
       ============================== */
    function testInitialState() public view {
        assertEq(pair.swapFeeBps(), SWAP_FEE_BPS);
        assertTrue(pair.token0() != address(0));
        assertTrue(pair.token1() != address(0));
        assertEq(pair.name(), NAME);
        assertEq(pair.symbol(), SYMBOL);
        assertEq(pair.decimals(), 18);
    }

    /* ==============================
      Test TransferFrom - Success Cases
       ============================== */
    function testTransferFrom_Success() public {
        mintPoolUsdcWeth();
        uint256 lpBalance = pair.balanceOf(USER1);
        assertGt(lpBalance, 0, "USER1 should have LP tokens");

        address recipient = address(0x1234);
        uint256 transferAmount = lpBalance / 2;

        // USER1 approves USER2 to transfer LP tokens
        vm.startPrank(USER1);
        pair.approve(USER2, transferAmount);
        vm.stopPrank();

        // USER2 executes transferFrom - should fail
        vm.startPrank(USER2);
        bool success = pair.transferFrom(USER1, recipient, transferAmount);
        vm.stopPrank();

        assertTrue(success, "transferFrom should succeed");
        assertEq(pair.balanceOf(USER1), lpBalance - transferAmount, "USER1 balance should decrease");
        assertEq(pair.balanceOf(recipient), transferAmount, "Recipient should receive tokens");
    }

    /* ==============================
      Test TransferFrom - Failure Cases
       ============================== */
    function testTransferFrom_InsufficientAllowance() public {
        mintPoolUsdcWeth();
        uint256 lpBalance = pair.balanceOf(USER1);
        assertGt(lpBalance, 0, "USER1 should have LP tokens");

        // Try transferFrom without sufficient approval
        vm.startPrank(USER2);
        vm.expectRevert();
        pair.transferFrom(USER1, address(0x1234), lpBalance);
        vm.stopPrank();
    }

    function testTransferFrom_InsufficientBalance() public {
        mintPoolUsdcWeth();
        uint256 lpBalance = pair.balanceOf(USER1);
        uint256 excessiveAmount = lpBalance + 1; // Amount exceeding actual balance

        // USER1 approves USER2 to transfer amount exceeding balance
        vm.startPrank(USER1);
        pair.approve(USER2, excessiveAmount);
        vm.stopPrank();

        // USER2 tries to transfer amount exceeding balance
        vm.startPrank(USER2);
        vm.expectRevert();
        pair.transferFrom(USER1, address(0x1234), excessiveAmount);
        vm.stopPrank();
    }

    /* ==============================
      Test Basic Transfer
       ============================== */
    function testTransfer_Success() public {
        mintPoolUsdcWeth();
        uint256 lpBalance = pair.balanceOf(USER1);
        address recipient = address(0x1234);
        uint256 transferAmount = lpBalance / 2;

        vm.startPrank(USER1);
        bool success = pair.transfer(recipient, transferAmount);
        vm.stopPrank();

        assertTrue(success, "transfer should succeed");
        assertEq(pair.balanceOf(USER1), lpBalance - transferAmount);
        assertEq(pair.balanceOf(recipient), transferAmount);
    }

    function testTransfer_InsufficientBalance() public {
        mintPoolUsdcWeth();
        uint256 lpBalance = pair.balanceOf(USER1);
        uint256 excessiveAmount = lpBalance + 1; // Amount exceeding actual balance

        vm.startPrank(USER1);
        vm.expectRevert();
        pair.transfer(address(0x1234), excessiveAmount);
        vm.stopPrank();
    }

    /* ==============================
      Test Approval Mechanisms
       ============================== */
    function testApprove_Success() public {
        uint256 approvalAmount = 1000 * 1e18;

        vm.startPrank(USER1);
        bool success = pair.approve(USER2, approvalAmount);
        vm.stopPrank();

        assertTrue(success, "approve should succeed");
        assertEq(pair.allowance(USER1, USER2), approvalAmount);
    }

    function testApprove_ZeroApproval() public {
        vm.startPrank(USER1);
        bool success = pair.approve(USER2, 0);
        vm.stopPrank();

        assertTrue(success, "zero approval should succeed");
        assertEq(pair.allowance(USER1, USER2), 0);
    }

    function testIncreaseAllowance() public {
        uint256 initialAmount = 100 * 1e18;
        uint256 increaseAmount = 50 * 1e18;

        vm.startPrank(USER1);
        pair.approve(USER2, initialAmount);
        bool success = pair.increaseAllowance(USER2, increaseAmount);
        vm.stopPrank();

        assertTrue(success);
        assertEq(pair.allowance(USER1, USER2), initialAmount + increaseAmount);
    }

    function testDecreaseAllowance() public {
        uint256 initialAmount = 100 * 1e18;
        uint256 decreaseAmount = 50 * 1e18;

        vm.startPrank(USER1);
        pair.approve(USER2, initialAmount);
        bool success = pair.decreaseAllowance(USER2, decreaseAmount);
        vm.stopPrank();

        assertTrue(success);
        assertEq(pair.allowance(USER1, USER2), initialAmount - decreaseAmount);
    }

    /* ==============================
      Test Token Metadata
       ============================== */
    function testTokenMetadata() public view {
        assertEq(pair.name(), NAME);
        assertEq(pair.symbol(), SYMBOL);
        assertEq(pair.decimals(), 18);
        assertEq(pair.totalSupply(), 0); // Initially no LP tokens
    }

    function testTokenMetadata_AfterMint() public {
        mintPoolUsdcWeth();
        uint256 totalSupply = pair.totalSupply();
        assertGt(totalSupply, 0);
        assertEq(pair.balanceOf(USER1), totalSupply - 1000); // USER1 has all initial LP tokens
    }

    /* ==============================
      Test Balance & Supply
       ============================== */
    function testBalanceOf_ZeroAddress() public view {
        assertEq(pair.balanceOf(address(0)), 0);
    }

    function testBalanceOf_NonExistentAddress() public view {
        assertEq(pair.balanceOf(address(0xdeadbeef)), 0);
    }

    function testTotalSupply_AfterMultipleMints() public {
        mintPoolUsdcWeth();
        uint256 initialSupply = pair.totalSupply();

        // Add more liquidity
        vm.startPrank(USER2);
        mintToAndTransferToContract(USER2, pairUsdcWeth, usdc, weth, 500 * 10 ** 6, 0.5 ether);
        uint256 lpTokenAmount = pair.mintLpToken(USER2);
        console.log("lpTokenAmount", lpTokenAmount);
        vm.stopPrank();

        uint256 newSupply = pair.totalSupply();
        assertGt(newSupply, initialSupply, "Total supply should increase after mint");
    }
}
