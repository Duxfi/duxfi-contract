// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/Test.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {MockERC} from "../mocks/MockERC.sol";
import {DuxFactory} from "../../src/core/DuxFactory.sol";
import {DuxPair} from "../../src/core/DuxPair.sol";
import {DuxRouter} from "../../src/periphery/DuxRouter.sol";

/**
 * @title DuxRouterTest
 * @notice Unit tests for DuxRouter contract
 */
contract DuxRouterAddLiqTest is BaseFixture, LiquidityFixture {
    DuxRouter router;
    DuxPair pair;
    uint256 constant MOCK_USDC = 1000 * 10 ** 6;
    uint256 constant MOCK_WETH = 1 * 10 ** 18;

    function setUp() public override {
        BaseFixture.setUp();
        router = new DuxRouter(factory);
        pair = DuxPair(pairUsdcWeth);
    }

    function testAddLiquidity_EmptyPool_Success() public {
        // must be before prank user
        mintAndApproveToContract(USER1, address(router), usdc, weth, AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);
        vm.startPrank(USER1);
        LiquidityState memory stateBefore = captureState(USER1, pairUsdcWeth, usdc, weth);

        (uint256 actualAmountUsdc, uint256 actualAmountWeth, uint256 lpToken) =
            router.addLiquidity(usdc, AMOUNT_INIT_USDC, weth, AMOUNT_INIT_WETH);
        LiquidityState memory stateAfter = captureState(USER1, pairUsdcWeth, usdc, weth);

        uint256 iniExpectedToken = getLpTokenForEmptyPool(AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);

        assertEq(actualAmountUsdc, AMOUNT_INIT_USDC, "USDC deposit amount should match expected initial deposit");
        assertEq(actualAmountWeth, AMOUNT_INIT_WETH, "WETH deposit amount should match expected initial deposit");
        assertEq(lpToken, iniExpectedToken, "LP tokens minted should match calculated expected amount");
        assertEq(pair.balanceOf(USER1), iniExpectedToken, "User LP token balance should equal minted amount");
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

    function testAddLiquidity_ExistingPool_Success() public {
        address user = USER1;
        mintPoolUsdcWeth();
        // set up transaction
        uint256 additionalUsdc = 500 * 10 ** 6;
        uint256 additionalWeth = 0.3 * 10 ** 18;
        mintAndApproveToContract(user, address(router), usdc, weth, additionalUsdc, additionalWeth);

        vm.startPrank(user);
        // captured state before transaction
        LiquidityState memory stateBefore = captureState(user, pairUsdcWeth, usdc, weth);

        // run transaction
        (uint256 actualAmountUsdc, uint256 actualAmountWeth, uint256 lpToken) =
            router.addLiquidity(usdc, additionalUsdc, weth, additionalWeth);
        // test returned actual added amount
        if (actualAmountUsdc == additionalUsdc) {
            assertGt(additionalWeth, actualAmountWeth);
        } else {
            assertGt(additionalUsdc, actualAmountUsdc);
        }

        uint256 expectedLp = getLpTokenForExistingPool(
            actualAmountUsdc, actualAmountWeth, stateBefore.totalSupply, stateBefore.reserveA, stateBefore.reserveB
        );

        assertEq(lpToken, expectedLp, "LP tokens minted should match calculated expected amount for existing pool");
        LiquidityState memory stateAfter = captureState(user, pairUsdcWeth, usdc, weth);

        assertEq(stateAfter.reserveA, stateBefore.reserveA + actualAmountUsdc, "reserveA should be updated");
        assertEq(stateAfter.reserveB, stateBefore.reserveB + actualAmountWeth, "reserveB should be updated");
        assertEq(stateAfter.lpBalance, stateBefore.lpBalance + lpToken, "lpBalance should be updated");
        assertEq(stateAfter.userBalanceA, stateBefore.userBalanceA - actualAmountUsdc, "userBalanceA should be updated");
        assertEq(stateAfter.userBalanceB, stateBefore.userBalanceB - actualAmountWeth, "userBalanceB should be updated");

        vm.stopPrank();
    }

    function testAddLiquidity_ZeroAmountA_Reverts() public {
        vm.startPrank(USER1);
        super.mintAndApproveToContract(USER1, address(router), usdc, weth, MOCK_USDC, MOCK_WETH);
        vm.expectRevert(DuxRouter.DuxRouter_ZeroAmount.selector);
        router.addLiquidity(usdc, 0, weth, MOCK_WETH);
        vm.stopPrank();
    }

    function testAddLiquidity_ZeroAmountB_Reverts() public {
        vm.startPrank(USER1);
        super.mintAndApproveToContract(USER1, address(router), usdc, weth, MOCK_USDC, MOCK_WETH);
        vm.expectRevert(DuxRouter.DuxRouter_ZeroAmount.selector);
        router.addLiquidity(usdc, MOCK_USDC, weth, 0);
        vm.stopPrank();
    }

    function testAddLiquidity_ZeroAddressA_Reverts() public {
        vm.startPrank(USER1);
        super.mintAndApproveToContract(USER1, address(router), usdc, weth, MOCK_USDC, MOCK_WETH);
        vm.expectRevert(DuxRouter.DuxRouter_ZeroAddress.selector);
        router.addLiquidity(address(0), MOCK_USDC, weth, MOCK_WETH);
        vm.stopPrank();
    }

    function testAddLiquidity_ZeroAddressB_Reverts() public {
        vm.startPrank(USER1);
        super.mintAndApproveToContract(USER1, address(router), usdc, weth, MOCK_USDC, MOCK_WETH);

        vm.expectRevert(DuxRouter.DuxRouter_ZeroAddress.selector);
        router.addLiquidity(usdc, MOCK_USDC, address(0), MOCK_WETH);
        vm.stopPrank();
    }

    function testAddLiquidity_SameToken_Reverts() public {
        vm.startPrank(USER1);
        super.mintAndApproveToContract(USER1, address(router), usdc, weth, MOCK_USDC, MOCK_WETH);
        vm.expectRevert();
        router.addLiquidity(usdc, MOCK_USDC, usdc, MOCK_WETH);
        vm.stopPrank();
    }

    function testAddLiquidity_UnknownToken_Reverts() public {
        vm.startPrank(USER1);
        MockERC unknownToken = new MockERC("Unknown", "UNK", 18);
        unknownToken.mint(USER1, 1000 * 10 ** 18);
        unknownToken.approve(address(router), 1000 * 10 ** 18);
        vm.expectRevert();
        router.addLiquidity(usdc, MOCK_USDC, address(unknownToken), 1000 * 10 ** 18);
        vm.stopPrank();
    }

    function testAddLiquidity_ZeroDeposite_Reverts() public {
        mintPoolUsdcWeth();
        vm.startPrank(USER1);
        uint256 tinyAmount = 1; // 1 wei
        super.mintAndApproveToContract(USER1, address(router), usdc, weth, tinyAmount, tinyAmount);

        vm.expectRevert();
        router.addLiquidity(usdc, tinyAmount, weth, tinyAmount);
        vm.stopPrank();
    }

    //ensure token0-token1 pair = token1-token0 pair
    function testAddLiquidity_TokenSorting() public {
        mintPoolUsdcWeth();
        mintAndApproveToContract(USER1, address(router), usdc, weth, MOCK_USDC * 2, MOCK_WETH * 2);

        vm.startPrank(USER1);
        (,, uint256 lpToken1) = router.addLiquidity(usdc, MOCK_USDC, weth, MOCK_WETH);
        (,, uint256 lpToken2) = router.addLiquidity(weth, MOCK_WETH, usdc, MOCK_USDC);
        assertEq(lpToken1, lpToken2, "LP tokens should be identical regardless of token order");
        vm.stopPrank();
    }

    /**
     * @notice Test that addLiquidity automatically adjusts imbalanced liquidity amounts to match pool ratio
     * @dev Verifies that when user provides funds not matching the k-value ratio, the contract automatically
     * calculates and uses the optimal amounts that maintain pool price integrity using simple, safe values
     */
    function testAddLiquidity_ImbalancedAmounts_AutomaticAdjustment() public {
        // 1. Use the existing helper method to create a pool with sufficient initial liquidity
        // This ensures we meet the MINIMUM_LIQUIDITY requirement (1000) and avoids overflow
        mintPoolUsdcWeth();

        address user = USER1;

        // Get current state of the pool
        LiquidityState memory stateBefore = captureState(user, pairUsdcWeth, usdc, weth);

        // 2. Try to add liquidity with imbalanced amounts
        uint256 additionalUsdc = (MOCK_USDC * 10) / 100; // 10% of initial USDC
        uint256 additionalWeth = (MOCK_WETH * 50) / 100; // 50% of initial WETH (deliberately imbalanced)

        // Mint and approve additional tokens
        mintAndApproveToContract(user, address(router), usdc, weth, additionalUsdc, additionalWeth);

        vm.startPrank(user);

        // Display key information for debugging
        console.log("Before adding liquidity:");
        console.log("  USDC reserve: %s", stateBefore.reserveB);
        console.log("  WETH reserve: %s", stateBefore.reserveA);
        console.log("  Amounts intended to add - USDC: %s, WETH: %s", additionalUsdc, additionalWeth);

        // Call addLiquidity with imbalanced amounts
        (uint256 actualAmountUsdc, uint256 actualAmountWeth,) =
            router.addLiquidity(usdc, additionalUsdc, weth, additionalWeth);

        // Calculate expected optimal WETH amount based on pool ratio
        // Correct formula: (additionalUSDC * reserveWETH) / reserveUSDC
        uint256 expectedOptimalWeth = (additionalUsdc * stateBefore.reserveB) / stateBefore.reserveA;

        // Display actual results
        console.log("After adding liquidity:");
        console.log("  Amounts actually added - USDC: %s, WETH: %s", actualAmountUsdc, actualAmountWeth);
        console.log("  Expected optimal WETH amount: %s", expectedOptimalWeth);

        // Verify core automatic adjustment behavior
        assertEq(actualAmountUsdc, additionalUsdc, "Should use all USDC");
        assertEq(actualAmountWeth, expectedOptimalWeth, "Should use optimal WETH amount based on pool ratio");
        assertTrue(actualAmountWeth < additionalWeth, "Should not use all WETH");

        // Verify pool reserves were updated correctly
        LiquidityState memory stateAfter = captureState(user, pairUsdcWeth, usdc, weth);
        assertEq(stateAfter.reserveA, stateBefore.reserveA + actualAmountUsdc, "WETH reserve should be updated");
        assertEq(stateAfter.reserveB, stateBefore.reserveB + actualAmountWeth, "USDC reserve should be updated");

        vm.stopPrank();
    }

    /**
     * @notice Test that addLiquidity creates a new pair when it doesn't exist
     * @dev Verifies that when adding liquidity to a non-existent pair, the contract automatically
     * creates the pair using the factory contract
     */
    function testAddLiquidity_CreateNewPair() public {
        // Create new tokens for testing
        MockERC newTokenA = new MockERC("New Token A", "NTA", 18);
        MockERC newTokenB = new MockERC("New Token B", "NTB", 18);

        // Mint tokens to user
        uint256 initialAmountA = 1000 * 10 ** 18;
        uint256 initialAmountB = 500 * 10 ** 18;
        newTokenA.mint(USER1, initialAmountA);
        newTokenB.mint(USER1, initialAmountB);

        // Approve router to spend tokens
        vm.startPrank(USER1);
        newTokenA.approve(address(router), initialAmountA);
        newTokenB.approve(address(router), initialAmountB);

        // Verify pair doesn't exist yet
        address pairBefore = DuxFactory(factory).getPair(address(newTokenA), address(newTokenB));
        assertEq(pairBefore, address(0), "Pair should not exist before adding liquidity");

        // Add liquidity - this should create a new pair
        (uint256 actualAmountA, uint256 actualAmountB, uint256 lpToken) =
            router.addLiquidity(address(newTokenA), initialAmountA, address(newTokenB), initialAmountB);

        // Verify pair was created
        address pairAfter = DuxFactory(factory).getPair(address(newTokenA), address(newTokenB));
        assertTrue(pairAfter != address(0), "Pair should be created after adding liquidity");

        // Verify amounts
        assertEq(actualAmountA, initialAmountA, "Should use all of token A");
        assertEq(actualAmountB, initialAmountB, "Should use all of token B");

        // Verify LP tokens were minted
        assertTrue(lpToken > 0, "Should mint LP tokens");
        assertEq(DuxPair(pairAfter).balanceOf(USER1), lpToken, "User should receive LP tokens");

        // Verify reserves
        (uint256 reserve0, uint256 reserve1,) = DuxPair(pairAfter).getReserves();
        assertEq(reserve0, actualAmountA, "Reserve0 should match deposited amount");
        assertEq(reserve1, actualAmountB, "Reserve1 should match deposited amount");

        vm.stopPrank();
    }

    /**
     * @notice Test that addLiquidity creates a new pair with one existing token
     * @dev Verifies that when adding liquidity with one existing token and one new token,
     * the contract automatically creates the pair using the factory contract
     */
    function testAddLiquidity_CreateNewPairWithExistingToken() public {
        // Create new token for testing with existing USDC
        MockERC newToken = new MockERC("New Token", "NEW", 18);

        // Mint tokens to user
        uint256 initialAmountNew = 1000 * 10 ** 18;
        uint256 initialAmountUsdc = 500 * 10 ** 6; // USDC has 6 decimals
        newToken.mint(USER1, initialAmountNew);
        // Mint USDC to user as well since BaseFixture doesn't do this automatically
        MockERC(usdc).mint(USER1, initialAmountUsdc);

        // Approve router to spend tokens
        vm.startPrank(USER1);
        newToken.approve(address(router), initialAmountNew);
        MockERC(usdc).approve(address(router), initialAmountUsdc);

        // Verify pair doesn't exist yet
        address pairBefore = DuxFactory(factory).getPair(address(newToken), usdc);
        assertEq(pairBefore, address(0), "Pair should not exist before adding liquidity");

        // Add liquidity - this should create a new pair
        (uint256 actualAmountNew, uint256 actualAmountUsdc, uint256 lpToken) =
            router.addLiquidity(address(newToken), initialAmountNew, usdc, initialAmountUsdc);

        // Verify pair was created
        address pairAfter = DuxFactory(factory).getPair(address(newToken), usdc);
        assertTrue(pairAfter != address(0), "Pair should be created after adding liquidity");

        // Verify amounts
        assertEq(actualAmountNew, initialAmountNew, "Should use all of new token");
        assertEq(actualAmountUsdc, initialAmountUsdc, "Should use all of USDC");

        // Verify LP tokens were minted
        assertTrue(lpToken > 0, "Should mint LP tokens");
        assertEq(DuxPair(pairAfter).balanceOf(USER1), lpToken, "User should receive LP tokens");

        // Verify reserves
        (uint256 reserve0, uint256 reserve1,) = DuxPair(pairAfter).getReserves();
        // Need to check which token is token0/token1 due to sorting
        if (address(newToken) < usdc) {
            // newToken is token0
            assertEq(reserve0, actualAmountNew, "Reserve0 should match deposited amount of new token");
            assertEq(reserve1, actualAmountUsdc, "Reserve1 should match deposited amount of USDC");
        } else {
            // usdc is token0
            assertEq(reserve0, actualAmountUsdc, "Reserve0 should match deposited amount of USDC");
            assertEq(reserve1, actualAmountNew, "Reserve1 should match deposited amount of new token");
        }

        vm.stopPrank();
    }

    /**
     * @notice Test that addLiquidity reverts when trying to create a pair with identical tokens
     * @dev Verifies that the contract properly handles the edge case of identical token addresses
     */
    function testAddLiquidity_CreateNewPair_IdenticalTokens_Reverts() public {
        // Create new token
        MockERC token = new MockERC("Token", "TKN", 18);

        // Mint tokens to user
        uint256 initialAmount = 1000 * 10 ** 18;
        token.mint(USER1, initialAmount);

        // Approve router to spend tokens
        vm.startPrank(USER1);
        token.approve(address(router), initialAmount);

        // Try to add liquidity with identical tokens - should revert
        vm.expectRevert(); // Expect revert from factory's DuxFactory_IdenticalAddresses error
        router.addLiquidity(address(token), initialAmount, address(token), initialAmount);

        vm.stopPrank();
    }
}
