// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {DuxFaucet} from "../../src/periphery/DuxFaucet.sol";
import {MockERC} from "../mocks/MockERC.sol";

contract DuxFaucetTest is Test {
    DuxFaucet public faucet;
    MockERC public mockToken;
    MockERC public anotherToken;

    address public owner = address(1);
    address public user1 = address(2); // New user
    address public user2 = address(3); // Existing user
    address public user3 = address(4); // Regular user

    // Token test parameters initialization
    address[] public tokensArray = new address[](1);
    uint256[] public amountsArray = new uint256[](1);
    uint256 public tokenDailyAmount = 100 * 10 ** 18;
    uint256 public initialTimestamp = 1000000 days; // Set a reasonable initial timestamp

    function setUp() public {
        vm.warp(initialTimestamp); // Set initial timestamp
        vm.startPrank(owner);
        mockToken = new MockERC("Mock Token", "MOCK", 18);
        anotherToken = new MockERC("Another Token", "ANOTHER", 18);

        // Mint initial tokens to owner for testing withdraw functionality
        mockToken.mint(owner, 10000 * 10 ** 18);
        anotherToken.mint(owner, 10000 * 10 ** 18);

        // Create parameter arrays
        address[] memory setupTokens = new address[](1);
        uint256[] memory dailyAmounts = new uint256[](1);
        setupTokens[0] = address(mockToken);
        dailyAmounts[0] = tokenDailyAmount;

        // Initialize with new constructor
        faucet = new DuxFaucet();

        // Transfer ownership to the owner address for testing
        faucet.transferOwnership(owner);

        // Set tokens and daily reward amounts
        faucet.setTokens(setupTokens, dailyAmounts);

        // Fund the contract with tokens
        mockToken.transferOwnership(address(faucet));
        vm.stopPrank();
    }

    // Test new user's first claim
    function testNewUserClaim() public {
        uint256 user1InitialTokenBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        // Verify token transfer
        assertEq(
            mockToken.balanceOf(user1),
            user1InitialTokenBalance + tokenDailyAmount,
            "User should receive daily token amount"
        );

        // Verify user status has been updated (rolling 24h timestamp)
        assertGt(faucet.lastDailyClaimTime(user1), 0, "User should have last claim timestamp recorded");
    }

    // Test existing user claim after 24 hours
    function testExistingUserClaim() public {
        // First make user2 an existing user
        vm.warp(initialTimestamp); // Reset to initial timestamp
        vm.startPrank(user2);
        faucet.claimDaily();
        vm.stopPrank();

        // Simulate 24 hours and a bit passing
        vm.warp(initialTimestamp + 1 days + 1);

        uint256 user2InitialTokenBalance = mockToken.balanceOf(user2);

        // Existing user claims again (should pass due to >= 24h)
        vm.startPrank(user2);
        faucet.claimDaily();
        vm.stopPrank();

        // Verify existing user received daily token
        assertEq(
            mockToken.balanceOf(user2),
            user2InitialTokenBalance + tokenDailyAmount,
            "User should receive daily token amount"
        );
    }

    // Test cannot claim within 24 hours for the same user
    function testCannotClaimWithin24Hours() public {
        vm.warp(initialTimestamp); // Reset to initial timestamp
        vm.startPrank(user1);
        faucet.claimDaily(); // First claim succeeds

        vm.expectRevert(bytes("Already claimed in cooldown period"));
        faucet.claimDaily(); // Second claim within 24h should fail
        vm.stopPrank();
    }

    // Test token management functionality
    function testTokenManagement() public {
        vm.warp(initialTimestamp); // Reset to initial timestamp
        uint256 anotherTokenDailyAmount = 200 * 10 ** 18;

        // Add new token
        vm.startPrank(owner);
        address[] memory newTokens = new address[](1);
        uint256[] memory newDailyAmounts = new uint256[](1);
        newTokens[0] = address(anotherToken);
        newDailyAmounts[0] = anotherTokenDailyAmount;
        faucet.setTokens(newTokens, newDailyAmounts);
        // Transfer ownership of anotherToken to faucet so it can mint tokens
        anotherToken.transferOwnership(address(faucet));
        vm.stopPrank();

        // Claim reward
        vm.startPrank(user3);
        faucet.claimDaily();
        vm.stopPrank();

        // Verify both tokens were claimed (minted)
        assertEq(mockToken.balanceOf(user3), tokenDailyAmount, "User should receive first token");
        assertEq(anotherToken.balanceOf(user3), anotherTokenDailyAmount, "User should receive second token");

        // Remove token
        vm.startPrank(owner);
        faucet.removeToken(address(anotherToken));
        vm.stopPrank();

        // Simulate 24 hours passing
        vm.warp(initialTimestamp + 1 days + 1);

        // Claim again, should only get the first token
        uint256 user3TokenBalance = mockToken.balanceOf(user3);
        vm.startPrank(user3);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(
            mockToken.balanceOf(user3), user3TokenBalance + tokenDailyAmount, "User should receive first token again"
        );
        assertEq(anotherToken.balanceOf(user3), anotherTokenDailyAmount, "User should not receive removed token");
    }

    // Test tokens list functionality
    function testTokensList() public {
        address[] memory faucetTokens = faucet.getTokens();
        assertEq(faucetTokens.length, 1, "There should be one token initially");
        assertEq(faucetTokens[0], address(mockToken), "Token address should match");

        // Add second token
        vm.startPrank(owner);
        address[] memory newTokens2 = new address[](1);
        uint256[] memory newDailyAmounts2 = new uint256[](1);
        newTokens2[0] = address(anotherToken);
        newDailyAmounts2[0] = 50 * 10 ** 18;
        faucet.setTokens(newTokens2, newDailyAmounts2);
        vm.stopPrank();

        faucetTokens = faucet.getTokens();
        assertEq(faucetTokens.length, 2, "There should be two tokens after adding");
    }

    // Test TokenClaimed event emission
    function testTokenClaimedEvent() public {
        vm.warp(initialTimestamp); // Reset to initial timestamp
        address user = user1;
        bytes32 eventSignature = keccak256("TokenClaimed(address,uint256,address[],uint256[])");

        // Record all logs emitted during the transaction
        vm.recordLogs();

        // Trigger the claim to emit the event
        vm.startPrank(user);
        faucet.claimDaily();
        vm.stopPrank();

        // Retrieve the emitted logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find TokenClaimed event in logs
        bool foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature && logs[i].emitter == address(faucet)) {
                // Extract the indexed 'who' parameter from topics
                address who = address(uint160(uint256(logs[i].topics[1])));
                assertEq(who, user, "Claimer address should match");
                foundEvent = true;
                break;
            }
        }

        // Verify TokenClaimed event was emitted
        assertTrue(foundEvent, "TokenClaimed event should be emitted");

        // Now let's add a second token and test again to verify the event works with multiple tokens
        vm.startPrank(owner);
        address[] memory newTokens = new address[](1);
        uint256[] memory newAmounts = new uint256[](1);
        newTokens[0] = address(anotherToken);
        newAmounts[0] = 200 * 10 ** 18;
        faucet.setTokens(newTokens, newAmounts);
        // Transfer ownership of anotherToken to faucet so it can mint tokens
        anotherToken.transferOwnership(address(faucet));
        vm.stopPrank();

        // Simulate next day (>= 24h)
        vm.warp(initialTimestamp + 1 days + 1);

        // Record logs again
        vm.recordLogs();

        // Trigger the second claim
        vm.startPrank(user);
        faucet.claimDaily();
        vm.stopPrank();

        // Retrieve the logs again
        logs = vm.getRecordedLogs();

        // Find TokenClaimed event in logs again
        foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature && logs[i].emitter == address(faucet)) {
                // Extract the indexed 'who' parameter from topics
                address who = address(uint160(uint256(logs[i].topics[1])));
                assertEq(who, user, "Claimer address should match in second claim");
                foundEvent = true;
                break;
            }
        }

        // Verify TokenClaimed event was emitted in second claim
        assertTrue(foundEvent, "TokenClaimed event should be emitted in second claim");
    }

    // Test updateTokenAmount function
    function testUpdateTokenAmount() public {
        vm.warp(initialTimestamp);
        uint256 newAmount = 500 * 10 ** 18;

        vm.startPrank(owner);
        faucet.updateTokenAmount(address(mockToken), newAmount);
        vm.stopPrank();

        // Wait for cooldown to pass
        vm.warp(initialTimestamp + 1 days + 1);

        uint256 user1InitialBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), user1InitialBalance + newAmount, "User should receive updated token amount");
    }

    // Test clearAllTokens function
    function testClearAllTokens() public {
        vm.startPrank(owner);
        // Add another token first
        address[] memory newTokens = new address[](1);
        uint256[] memory newAmounts = new uint256[](1);
        newTokens[0] = address(anotherToken);
        newAmounts[0] = 200 * 10 ** 18;
        faucet.setTokens(newTokens, newAmounts);
        vm.stopPrank();

        // Verify two tokens exist
        address[] memory tokensBefore = faucet.getTokens();
        assertEq(tokensBefore.length, 2, "Should have 2 tokens before clear");

        // Clear all tokens
        vm.startPrank(owner);
        faucet.clearAllTokens();
        vm.stopPrank();

        // Verify no tokens remain
        address[] memory tokensAfter = faucet.getTokens();
        assertEq(tokensAfter.length, 0, "Should have 0 tokens after clear");
    }

    // Test setCooldown function
    function testSetCooldown() public {
        uint256 newCooldown = 12 hours;

        vm.startPrank(owner);
        faucet.setCooldown(newCooldown);
        vm.stopPrank();

        // Wait half of original cooldown (but more than new 12h)
        vm.warp(initialTimestamp + 13 hours);

        uint256 user1InitialBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), user1InitialBalance + tokenDailyAmount, "User should claim with new cooldown");
    }

    // Test setCooldown revert when exceeding max
    function testSetCooldownExceedsMax() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Cooldown too long"));
        faucet.setCooldown(31 days);
        vm.stopPrank();
    }

    // Test pause functionality
    function testPause() public {
        vm.startPrank(owner);
        faucet.pause();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        faucet.claimDaily();
        vm.stopPrank();
    }

    // Test unpause functionality
    function testUnpause() public {
        // First pause
        vm.startPrank(owner);
        faucet.pause();
        faucet.unpause();
        vm.stopPrank();

        // Should be able to claim after unpause
        vm.warp(initialTimestamp);
        uint256 user1InitialBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), user1InitialBalance + tokenDailyAmount, "User should claim after unpause");
    }

    // Test withdrawERC20 function
    function testWithdrawERC20() public {
        // Give faucet some tokens directly using deal
        deal(address(mockToken), address(faucet), 1000 * 10 ** 18);

        uint256 ownerInitialBalance = mockToken.balanceOf(owner);
        uint256 faucetBalance = mockToken.balanceOf(address(faucet));

        vm.startPrank(owner);
        faucet.withdrawERC20(address(mockToken), faucetBalance);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(owner), ownerInitialBalance + faucetBalance, "Owner should receive tokens");
        assertEq(mockToken.balanceOf(address(faucet)), 0, "Faucet should have 0 tokens");
    }

    // Test removeToken function
    function testRemoveToken() public {
        vm.startPrank(owner);
        faucet.removeToken(address(mockToken));
        vm.stopPrank();

        address[] memory tokensAfter = faucet.getTokens();
        assertEq(tokensAfter.length, 0, "Token should be removed");

        // Verify cannot claim removed token
        vm.warp(initialTimestamp + 1 days + 1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), 0, "User should not receive removed token");
    }

    // Test cannot claim when contract is paused
    function testCannotClaimWhenPaused() public {
        vm.warp(initialTimestamp);

        vm.startPrank(owner);
        faucet.pause();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Pausable: paused");
        faucet.claimDaily();
        vm.stopPrank();
    }
}
