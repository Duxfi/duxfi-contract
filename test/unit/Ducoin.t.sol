// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DuCoin} from "../../src/core/DuCoin.sol";

/**
 * @title DuCoinTest
 * @notice Unit tests for DuCoin contract
 */
contract DuCoinTest is Test {
    DuCoin public duCoin;
    address public owner = address(this);
    address public nonOwner = address(0x1234);
    address public recipient = address(0x4567);

    string constant TOKEN_NAME = "DuCoin";
    string constant TOKEN_SYMBOL = "DUC";
    uint8 constant TOKEN_DECIMALS = 18;

    function setUp() public {
        duCoin = new DuCoin(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
    }

    /* =============================
       DEPLOYMENT TESTS
       ============================= */

    function testDeployment_Success() public view {
        assertEq(duCoin.name(), TOKEN_NAME);
        assertEq(duCoin.symbol(), TOKEN_SYMBOL);
        assertEq(duCoin.decimals(), TOKEN_DECIMALS);
        assertEq(duCoin.totalSupply(), 0);
        assertEq(duCoin.owner(), owner);
    }

    function testDeployment_CustomDecimals() public {
        uint8 customDecimals = 6;
        DuCoin customDecimalsCoin = new DuCoin(TOKEN_NAME, TOKEN_SYMBOL, customDecimals);
        assertEq(customDecimalsCoin.decimals(), customDecimals);
    }

    /* =============================
       MINTING TESTS
       ============================= */

    function testMint_Success() public {
        uint256 mintAmount = 1000 * 10 ** uint256(TOKEN_DECIMALS);
        uint256 expectedTotalSupply = mintAmount;
        uint256 expectedRecipientBalance = mintAmount;

        duCoin.mint(recipient, mintAmount);

        assertEq(duCoin.totalSupply(), expectedTotalSupply);
        assertEq(duCoin.balanceOf(recipient), expectedRecipientBalance);
    }

    function testMint_NonOwner_Reverts() public {
        uint256 mintAmount = 1000 * 10 ** uint256(TOKEN_DECIMALS);

        vm.prank(nonOwner);
        vm.expectRevert("DuCoin: caller is not minter");
        duCoin.mint(recipient, mintAmount);
    }

    function testMint_ZeroAmount_Success() public {
        uint256 mintAmount = 0;
        uint256 expectedTotalSupply = 0;

        duCoin.mint(recipient, mintAmount);

        assertEq(duCoin.totalSupply(), expectedTotalSupply);
        assertEq(duCoin.balanceOf(recipient), 0);
    }

    function testMint_LargeAmount_Success() public {
        uint256 mintAmount = type(uint128).max;
        uint256 expectedTotalSupply = mintAmount;

        duCoin.mint(recipient, mintAmount);

        assertEq(duCoin.totalSupply(), expectedTotalSupply);
        assertEq(duCoin.balanceOf(recipient), mintAmount);
    }

    function testMint_MultipleTimes() public {
        uint256 firstMint = 1000 * 10 ** uint256(TOKEN_DECIMALS);
        uint256 secondMint = 2000 * 10 ** uint256(TOKEN_DECIMALS);
        uint256 expectedTotalSupply = firstMint + secondMint;

        duCoin.mint(recipient, firstMint);
        duCoin.mint(recipient, secondMint);

        assertEq(duCoin.totalSupply(), expectedTotalSupply);
        assertEq(duCoin.balanceOf(recipient), expectedTotalSupply);
    }

    function testMint_DifferentRecipients() public {
        uint256 mintAmount = 1000 * 10 ** uint256(TOKEN_DECIMALS);
        address recipient2 = address(0x89AB);

        duCoin.mint(recipient, mintAmount);
        duCoin.mint(recipient2, mintAmount);

        assertEq(duCoin.totalSupply(), mintAmount * 2);
        assertEq(duCoin.balanceOf(recipient), mintAmount);
        assertEq(duCoin.balanceOf(recipient2), mintAmount);
    }

    /* =============================
       OWNERSHIP TESTS
       ============================= */

    function testOwner_TransferOwnership() public {
        duCoin.addMinter(nonOwner);
        duCoin.transferOwnership(nonOwner);
        assertEq(duCoin.owner(), nonOwner);

        // New owner can now mint
        vm.prank(nonOwner);
        uint256 mintAmount = 1000 * 10 ** uint256(TOKEN_DECIMALS);
        duCoin.mint(recipient, mintAmount);
        assertEq(duCoin.balanceOf(recipient), mintAmount);
    }

    /* =============================
       ERC20 INHERITED FUNCTIONS TESTS
       ============================= */

    function testERC20_Transfer_Success() public {
        uint256 mintAmount = 1000 * 10 ** uint256(TOKEN_DECIMALS);
        uint256 transferAmount = 500 * 10 ** uint256(TOKEN_DECIMALS);
        address sender = recipient;
        address receiver = address(0x89AB);

        // First mint some tokens to sender
        duCoin.mint(sender, mintAmount);

        // Switch to sender's identity to perform transfer
        vm.startPrank(sender);
        bool success = duCoin.transfer(receiver, transferAmount);
        vm.stopPrank();

        assertTrue(success);
        assertEq(duCoin.balanceOf(sender), mintAmount - transferAmount);
        assertEq(duCoin.balanceOf(receiver), transferAmount);
    }

    function testERC20_ApproveAndTransferFrom_Success() public {
        uint256 mintAmount = 1000 * 10 ** uint256(TOKEN_DECIMALS);
        uint256 approveAmount = 500 * 10 ** uint256(TOKEN_DECIMALS);
        uint256 transferAmount = 300 * 10 ** uint256(TOKEN_DECIMALS);
        address ownerOfTokens = recipient;
        address spender = address(0x89AB);
        address receiver = address(0xCDEF);

        // First mint some tokens to ownerOfTokens
        duCoin.mint(ownerOfTokens, mintAmount);

        // Authorize spender to use tokens
        vm.startPrank(ownerOfTokens);
        duCoin.approve(spender, approveAmount);
        vm.stopPrank();

        // Spender performs transferFrom operation
        vm.startPrank(spender);
        bool success = duCoin.transferFrom(ownerOfTokens, receiver, transferAmount);
        vm.stopPrank();

        assertTrue(success);
        assertEq(duCoin.balanceOf(ownerOfTokens), mintAmount - transferAmount);
        assertEq(duCoin.balanceOf(receiver), transferAmount);
        assertEq(duCoin.allowance(ownerOfTokens, spender), approveAmount - transferAmount);
    }
}
