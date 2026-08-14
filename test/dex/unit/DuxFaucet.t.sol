// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, Vm} from "forge-std/Test.sol";
import {DuxFaucet} from "@dex/periphery/DuxFaucet.sol";
import {MockERC} from "../mocks/MockERC.sol";

contract DuxFaucetTest is Test {
    DuxFaucet public faucet;
    MockERC public mockToken;
    MockERC public anotherToken;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);

    uint256 public constant MAX_TOKENS = 50;
    uint256 public tokenDailyAmount = 100 * 10 ** 18;
    uint256 public initialTimestamp = 1000000 days;

    function setUp() public {
        vm.warp(initialTimestamp);
        vm.startPrank(owner);
        mockToken = new MockERC("Mock Token", "MOCK", 18);
        anotherToken = new MockERC("Another Token", "ANOTHER", 18);

        mockToken.mint(owner, 10000 * 10 ** 18);
        anotherToken.mint(owner, 10000 * 10 ** 18);

        faucet = new DuxFaucet();

        faucet.addToken(address(mockToken), tokenDailyAmount);
        mockToken.transferOwnership(address(faucet));
        vm.stopPrank();
    }

    function testNewUserClaim() public {
        uint256 user1InitialTokenBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(
            mockToken.balanceOf(user1),
            user1InitialTokenBalance + tokenDailyAmount,
            "User should receive daily token amount"
        );

        assertGt(faucet.lastDailyClaimTime(user1), 0, "User should have last claim timestamp recorded");
    }

    function testExistingUserClaim() public {
        vm.warp(initialTimestamp);
        vm.startPrank(user2);
        faucet.claimDaily();
        vm.stopPrank();

        vm.warp(initialTimestamp + 1 days + 1);

        uint256 user2InitialTokenBalance = mockToken.balanceOf(user2);

        vm.startPrank(user2);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(
            mockToken.balanceOf(user2),
            user2InitialTokenBalance + tokenDailyAmount,
            "User should receive daily token amount"
        );
    }

    function testCannotClaimWithinCooldown() public {
        vm.warp(initialTimestamp);
        vm.startPrank(user1);
        faucet.claimDaily();

        vm.expectRevert(bytes("Already claimed in cooldown period"));
        faucet.claimDaily();
        vm.stopPrank();
    }

    function testAddToken() public {
        vm.startPrank(owner);
        faucet.addToken(address(anotherToken), 200 * 10 ** 18);
        anotherToken.transferOwnership(address(faucet));
        vm.stopPrank();

        vm.startPrank(user3);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user3), tokenDailyAmount, "User should receive first token");
        assertEq(anotherToken.balanceOf(user3), 200 * 10 ** 18, "User should receive second token");
    }

    function testCannotAddDuplicateToken() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Token already exists"));
        faucet.addToken(address(mockToken), tokenDailyAmount);
        vm.stopPrank();
    }

    function testCannotAddTokenZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Invalid token"));
        faucet.addToken(address(0), tokenDailyAmount);
        vm.stopPrank();
    }

    function testCannotAddTokenZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Invalid amount"));
        faucet.addToken(address(anotherToken), 0);
        vm.stopPrank();
    }

    function testTokenLimitReached() public {
        vm.startPrank(owner);
        for (uint256 i = 0; i < MAX_TOKENS - 1; i++) {
            MockERC t = new MockERC("T", "T", 18);
            faucet.addToken(address(t), 10 ** 18);
            t.transferOwnership(address(faucet));
        }

        MockERC extra = new MockERC("Extra", "EXTRA", 18);
        vm.expectRevert(bytes("Token limit reached"));
        faucet.addToken(address(extra), 10 ** 18);
        vm.stopPrank();
    }

    function testUpdateToken() public {
        vm.startPrank(owner);
        uint256 newAmount = 500 * 10 ** 18;
        faucet.updateToken(address(mockToken), newAmount, true);
        vm.stopPrank();

        vm.warp(initialTimestamp + 1 days + 1);

        uint256 user1InitialBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), user1InitialBalance + newAmount, "User should receive updated token amount");
    }

    function testUpdateTokenDisable() public {
        vm.startPrank(owner);
        faucet.updateToken(address(mockToken), tokenDailyAmount, false);
        vm.stopPrank();

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), 0, "User should not receive disabled token");
    }

    function testGetTokens() public {
        address[] memory faucetTokens = faucet.getTokens();
        assertEq(faucetTokens.length, 1, "There should be one token initially");
        assertEq(faucetTokens[0], address(mockToken), "Token address should match");

        vm.startPrank(owner);
        faucet.addToken(address(anotherToken), 50 * 10 ** 18);
        vm.stopPrank();

        faucetTokens = faucet.getTokens();
        assertEq(faucetTokens.length, 2, "There should be two tokens after adding");
    }

    function testTokenClaimedEvent() public {
        vm.warp(initialTimestamp);
        address user = user1;
        bytes32 eventSignature = keccak256("TokenClaimed(address,uint256,address[],uint256[])");

        vm.recordLogs();

        vm.startPrank(user);
        faucet.claimDaily();
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature && logs[i].emitter == address(faucet)) {
                address who = address(uint160(uint256(logs[i].topics[1])));
                assertEq(who, user, "Claimer address should match");
                (uint256 ts, address[] memory tokens, uint256[] memory amounts) =
                    abi.decode(logs[i].data, (uint256, address[], uint256[]));
                assertEq(ts, block.timestamp, "Timestamp should match");
                assertEq(tokens.length, 1, "Should claim 1 token in first claim");
                assertEq(tokens[0], address(mockToken), "Token should be mockToken");
                assertEq(amounts[0], tokenDailyAmount, "Amount should match");
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "TokenClaimed event should be emitted");

        vm.startPrank(owner);
        faucet.addToken(address(anotherToken), 200 * 10 ** 18);
        anotherToken.transferOwnership(address(faucet));
        vm.stopPrank();

        vm.warp(initialTimestamp + 1 days + 1);

        vm.recordLogs();

        vm.startPrank(user);
        faucet.claimDaily();
        vm.stopPrank();

        logs = vm.getRecordedLogs();

        foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature && logs[i].emitter == address(faucet)) {
                address who = address(uint160(uint256(logs[i].topics[1])));
                assertEq(who, user, "Claimer address should match in second claim");
                (uint256 ts, address[] memory tokens, uint256[] memory amounts) =
                    abi.decode(logs[i].data, (uint256, address[], uint256[]));
                assertEq(ts, block.timestamp, "Timestamp should match in second claim");
                assertEq(tokens.length, 2, "Should claim 2 tokens in second claim");
                assertEq(amounts.length, 2, "Should have 2 amounts");
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "TokenClaimed event should be emitted in second claim");
    }

    function testSetCooldown() public {
        uint256 newCooldown = 12 hours;

        vm.startPrank(owner);
        faucet.setCooldown(newCooldown);
        vm.stopPrank();

        vm.warp(initialTimestamp + 13 hours);

        uint256 user1InitialBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), user1InitialBalance + tokenDailyAmount, "User should claim with new cooldown");
    }

    function testSetCooldownExceedsMax() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Cooldown too long"));
        faucet.setCooldown(31 days);
        vm.stopPrank();
    }

    function testCooldownChangedEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit CooldownChanged(1 days, 12 hours);
        faucet.setCooldown(12 hours);
        vm.stopPrank();
    }

    function testPause() public {
        vm.startPrank(owner);
        faucet.pause();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("Pausable: paused");
        faucet.claimDaily();
        vm.stopPrank();
    }

    function testUnpause() public {
        vm.startPrank(owner);
        faucet.pause();
        faucet.unpause();
        vm.stopPrank();

        vm.warp(initialTimestamp);
        uint256 user1InitialBalance = mockToken.balanceOf(user1);

        vm.startPrank(user1);
        faucet.claimDaily();
        vm.stopPrank();

        assertEq(mockToken.balanceOf(user1), user1InitialBalance + tokenDailyAmount, "User should claim after unpause");
    }

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

    function testWithdrawERC20() public {
        deal(address(mockToken), address(faucet), 1000 * 10 ** 18);

        uint256 ownerInitialBalance = mockToken.balanceOf(owner);
        uint256 faucetBalance = mockToken.balanceOf(address(faucet));

        vm.startPrank(owner);
        faucet.withdrawERC20(address(mockToken), faucetBalance);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(owner), ownerInitialBalance + faucetBalance, "Owner should receive tokens");
        assertEq(mockToken.balanceOf(address(faucet)), 0, "Faucet should have 0 tokens");
    }

    function testWithdrawETH() public {
        deal(address(faucet), 5 ether);

        uint256 ownerInitialBalance = owner.balance;

        vm.startPrank(owner);
        faucet.withdrawETH();
        vm.stopPrank();

        assertEq(owner.balance, ownerInitialBalance + 5 ether, "Owner should receive ETH");
        assertEq(address(faucet).balance, 0, "Faucet should have 0 ETH");
    }

    function testWithdrawETHRevertsWhenEmpty() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("No ETH to withdraw"));
        faucet.withdrawETH();
        vm.stopPrank();
    }

    function testReceiveETH() public {
        uint256 amount = 2 ether;
        (bool ok,) = address(faucet).call{value: amount}("");
        assertTrue(ok, "ETH transfer should succeed");
        assertEq(address(faucet).balance, amount, "Faucet should receive ETH");
    }

    function testOnlyOwnerCanAddToken() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        faucet.addToken(address(anotherToken), 100 * 10 ** 18);
        vm.stopPrank();
    }

    function testOnlyOwnerCanUpdateToken() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        faucet.updateToken(address(mockToken), 100 * 10 ** 18, true);
        vm.stopPrank();
    }

    function testOnlyOwnerCanSetCooldown() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        faucet.setCooldown(12 hours);
        vm.stopPrank();
    }

    function testOnlyOwnerCanPause() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        faucet.pause();
        vm.stopPrank();
    }

    function testOnlyOwnerCanWithdrawERC20() public {
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        faucet.withdrawERC20(address(mockToken), 100);
        vm.stopPrank();
    }

    function testUpdateTokenRevertsForUnknownToken() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Token not in list"));
        faucet.updateToken(address(anotherToken), 100 * 10 ** 18, true);
        vm.stopPrank();
    }

    event CooldownChanged(uint256 oldCooldown, uint256 newCooldown);
}
