// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RouterFixture} from "../shared/fixtures/RouterFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {DuxPair} from "@dex/core/DuxPair.sol";
import {MockERC} from "../mocks/MockERC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SwapLib} from "../utils/SwapLib.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";

/**
 * @title DuxIntegrationTest
 * @notice Integration tests for the Dux DEX system
 * @dev Comprehensive tests that verify interactions between multiple components
 */
contract DuxIntegrationTest is RouterFixture, LiquidityFixture {
    uint256 constant SWAP_AMOUNT_USDC = 1000 * 10 ** 6;
    uint256 constant ADD_LIQUIDITY_AMOUNT_USDC = 10000 * 10 ** 6;
    uint256 constant ADD_LIQUIDITY_AMOUNT_WETH = 5 ether;
    uint256 constant REMOVE_LIQUIDITY_PERCENTAGE = 50; // 50%

    function setUp() public override(RouterFixture, BaseFixture) {
        RouterFixture.setUp();
    }

    /**
     * @notice Test a complete user journey: add liquidity, swap, remove liquidity
     */
    function testCompleteUserJourney() public {
        // User 1 adds initial liquidity
        mintAndApproveToContract(
            USER1, address(router), usdc, weth, ADD_LIQUIDITY_AMOUNT_USDC, ADD_LIQUIDITY_AMOUNT_WETH
        );
        vm.startPrank(USER1);
        (,, uint256 lpToken) = router.addLiquidity(usdc, ADD_LIQUIDITY_AMOUNT_USDC, weth, ADD_LIQUIDITY_AMOUNT_WETH);
        vm.stopPrank();

        // Verify initial liquidity was added correctly
        DuxPair pair = DuxPair(pairUsdcWeth);
        assertGt(lpToken, 0, "LP tokens should be minted");
        assertEq(pair.balanceOf(USER1), lpToken, "User should receive LP tokens");
        assertEq(
            pair.totalSupply(),
            lpToken + pair.MINIMUM_LIQUIDITY(),
            "Total supply should equal minted tokens plus minimum liquidity"
        );

        // User 2 swaps tokens
        mintAndApproveToContract(USER2, address(router), usdc, weth, SWAP_AMOUNT_USDC, 0);
        vm.startPrank(USER2);
        address[] memory paths = getUsdcWethPaths();
        uint256 wethBalanceBefore = IERC20(weth).balanceOf(USER2);
        (uint256[] memory amounts,) =
            router.swapExactTokensForTokens(SWAP_AMOUNT_USDC, 0, paths, USER2, block.timestamp);
        vm.stopPrank();

        // Verify swap was successful
        uint256 wethBalanceAfter = IERC20(weth).balanceOf(USER2);
        assertGt(wethBalanceAfter, wethBalanceBefore, "User should receive WETH");
        assertEq(wethBalanceAfter - wethBalanceBefore, amounts[1], "Received WETH should match expected amount");

        // User 1 removes a portion of their liquidity
        uint256 lpBalance = pair.balanceOf(USER1);
        uint256 lpAmountToRemove = (lpBalance * REMOVE_LIQUIDITY_PERCENTAGE) / 100;
        vm.startPrank(USER1);
        pair.approve(address(router), lpAmountToRemove);
        uint256 usdcBalanceBefore = IERC20(usdc).balanceOf(USER1);
        uint256 wethBalanceBeforeUser1 = IERC20(weth).balanceOf(USER1);
        (uint256 amountTokenUsdc, uint256 amountTokenWeth) = router.removeLiquidity(usdc, weth, lpAmountToRemove, USER1);
        vm.stopPrank();

        // Verify liquidity was removed correctly
        uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(USER1);
        uint256 wethBalanceAfterUser1 = IERC20(weth).balanceOf(USER1);
        assertGt(usdcBalanceAfter, usdcBalanceBefore, "User should receive USDC");
        assertGt(wethBalanceAfterUser1, wethBalanceBeforeUser1, "User should receive WETH");
        assertEq(usdcBalanceAfter - usdcBalanceBefore, amountTokenUsdc, "Received USDC should match expected amount");
        assertEq(
            wethBalanceAfterUser1 - wethBalanceBeforeUser1,
            amountTokenWeth,
            "Received WETH should match expected amount"
        );
        assertEq(pair.balanceOf(USER1), lpBalance - lpAmountToRemove, "LP balance should decrease");
    }

    /**
     * @notice Test complex multi-hop trading across multiple pairs
     */
    function testComplexMultiHopTrading() public {
        // Setup all pools with initial liquidity
        mintPoolAll();

        // User wants to trade USDC -> WETH -> DUX -> BTC -> DAI
        uint256 initialUsdcAmount = 1000 * 10 ** 6;
        mintAndApproveToContract(USER1, address(router), usdc, dai, initialUsdcAmount, 0);
        vm.startPrank(USER1);

        address[] memory paths = getPathsFromUsdcToDai();
        uint256 daiBalanceBefore = IERC20(dai).balanceOf(USER1);

        // Execute the multi-hop trade
        (uint256[] memory amounts,) =
            router.swapExactTokensForTokens(initialUsdcAmount, 0, paths, USER1, block.timestamp);
        vm.stopPrank();

        // Verify final token amount received
        uint256 daiBalanceAfter = IERC20(dai).balanceOf(USER1);
        assertGt(daiBalanceAfter, daiBalanceBefore, "User should receive DAI");
        assertEq(
            daiBalanceAfter - daiBalanceBefore, amounts[paths.length - 1], "Received DAI should match expected amount"
        );

        // Verify each intermediate swap step
        address[] memory pairs = getPairsFromUsdcToDai();
        for (uint256 i = 0; i < pairs.length; i++) {
            DuxPair currentPair = DuxPair(pairs[i]);
            (uint256 reserve0, uint256 reserve1,) = currentPair.getReserves();
            assertTrue(reserve0 > 0 && reserve1 > 0, "All reserves should remain positive after multi-hop trade");
        }
    }

    /**
     * @notice Test multiple users interacting with the protocol simultaneously
     */
    function testMultipleUsersInteraction() public {
        // Setup initial liquidity
        mintAndApproveToContract(
            USER1, address(router), usdc, weth, ADD_LIQUIDITY_AMOUNT_USDC, ADD_LIQUIDITY_AMOUNT_WETH
        );
        vm.startPrank(USER1);
        router.addLiquidity(usdc, ADD_LIQUIDITY_AMOUNT_USDC, weth, ADD_LIQUIDITY_AMOUNT_WETH);
        vm.stopPrank();

        // User 2 adds liquidity
        uint256 user2AmountUsdc = 5000 * 10 ** 6;
        uint256 user2AmountWeth = 2.5 ether;
        mintAndApproveToContract(USER2, address(router), usdc, weth, user2AmountUsdc, user2AmountWeth);
        vm.startPrank(USER2);
        router.addLiquidity(usdc, user2AmountUsdc, weth, user2AmountWeth);
        vm.stopPrank();

        // User 3 swaps tokens
        uint256 user3SwapAmount = 500 * 10 ** 6;
        mintAndApproveToContract(USER3, address(router), usdc, weth, user3SwapAmount, 0);
        vm.startPrank(USER3);
        address[] memory paths = getUsdcWethPaths();
        router.swapExactTokensForTokens(user3SwapAmount, 0, paths, USER3, block.timestamp);
        vm.stopPrank();

        // User 4 swaps tokens in the opposite direction
        uint256 user4SwapAmount = 1 ether;
        mintAndApproveToContract(USER4, address(router), weth, usdc, user4SwapAmount, 0);
        vm.startPrank(USER4);
        address[] memory reversePaths = new address[](2);
        reversePaths[0] = weth;
        reversePaths[1] = usdc;
        router.swapExactTokensForTokens(user4SwapAmount, 0, reversePaths, USER4, block.timestamp);
        vm.stopPrank();

        // User 1 removes all liquidity
        DuxPair pair = DuxPair(pairUsdcWeth);
        uint256 user1LpBalance = pair.balanceOf(USER1);
        vm.startPrank(USER1);
        pair.approve(address(router), user1LpBalance);
        router.removeLiquidity(usdc, weth, user1LpBalance, USER1);
        vm.stopPrank();

        // Verify system integrity after all operations
        (uint256 reserveUsdc, uint256 reserveWeth,) = pair.getReserves();
        assertTrue(reserveUsdc > 0 && reserveWeth > 0, "Reserves should remain positive");
        assertGt(pair.totalSupply(), 0, "Total supply should remain positive");
        assertEq(pair.balanceOf(USER1), 0, "User 1 should have no LP tokens left");
        assertGt(pair.balanceOf(USER2), 0, "User 2 should still have LP tokens");
    }

    /**
     * @notice Test protocol behavior when multiple pairs are created and interacted with
     */
    function testMultiplePairsInteraction() public {
        // Setup initial liquidity for all pools
        mintPoolAll();

        // Create a new pair (mockToken and USDC)
        address pairMockTokenUsdc = duxFactory.createPair(mockToken, usdc, SWAP_FEE_BPS, address(this));

        // Add liquidity to the new pair
        uint256 mockTokenAmount = 10000 * DECIMAL_18;
        uint256 usdcAmount = 5000 * DECIMAL_6;
        mintAndApproveToContract(USER1, pairMockTokenUsdc, mockToken, usdc, mockTokenAmount, usdcAmount);
        vm.startPrank(USER1);
        bool success1 = MockERC(mockToken).transfer(pairMockTokenUsdc, mockTokenAmount);
        bool success2 = MockERC(usdc).transfer(pairMockTokenUsdc, usdcAmount);
        require(success1 && success2, "Transfer failed");
        DuxPair(pairMockTokenUsdc).mintLpToken(USER1);
        vm.stopPrank();

        // Perform swaps across different pairs
        // 1. USDC -> WETH
        uint256 swapUsdcAmount = 1000 * DECIMAL_6;
        mintAndApproveToContract(USER2, address(router), usdc, weth, swapUsdcAmount, 0);
        vm.startPrank(USER2);
        address[] memory pathUsdcWeth = getUsdcWethPaths();
        router.swapExactTokensForTokens(swapUsdcAmount, 0, pathUsdcWeth, USER2, block.timestamp);
        vm.stopPrank();

        // 2. mockToken -> USDC
        uint256 swapMockTokenAmount = 1000 * DECIMAL_18;
        mintAndApproveToContract(USER3, pairMockTokenUsdc, mockToken, usdc, swapMockTokenAmount, 0);
        vm.startPrank(USER3);
        address[] memory pathMockTokenUsdc = new address[](2);
        pathMockTokenUsdc[0] = mockToken;
        pathMockTokenUsdc[1] = usdc;
        bool success = MockERC(mockToken).transfer(pairMockTokenUsdc, swapMockTokenAmount);
        assertTrue(success, "Transfer failed");
        (uint256 amount0Out, uint256 amount1Out,,,,) =
            SwapLib.getExpectedSwapOutput(pairMockTokenUsdc, swapMockTokenAmount, mockToken);
        DuxPair(pairMockTokenUsdc).swap(amount0Out, amount1Out, USER3, "");
        vm.stopPrank();

        // Verify all pairs remain functional
        DuxPair(pairUsdcWeth).getReserves();
        DuxPair(pairDuxWeth).getReserves();
        DuxPair(pairMockTokenUsdc).getReserves();

        // Ensure no pair has zero reserves
        (uint256 r0, uint256 r1,) = DuxPair(pairUsdcWeth).getReserves();
        assertTrue(r0 > 0 && r1 > 0, "USDC-WETH pair should have positive reserves");

        (r0, r1,) = DuxPair(pairDuxWeth).getReserves();
        assertTrue(r0 > 0 && r1 > 0, "WETH-DUX pair should have positive reserves");

        (r0, r1,) = DuxPair(pairMockTokenUsdc).getReserves();
        assertTrue(r0 > 0 && r1 > 0, "MOCK-USDC pair should have positive reserves");
    }

    /**
     * @notice Test system behavior under stress conditions
     */
    function testSystemUnderStress() public {
        // Setup initial liquidity
        mintAndApproveToContract(
            USER1, address(router), usdc, weth, ADD_LIQUIDITY_AMOUNT_USDC, ADD_LIQUIDITY_AMOUNT_WETH
        );
        vm.startPrank(USER1);
        router.addLiquidity(usdc, ADD_LIQUIDITY_AMOUNT_USDC, weth, ADD_LIQUIDITY_AMOUNT_WETH);
        vm.stopPrank();

        // Perform multiple consecutive swaps to stress the system
        address[] memory paths = getUsdcWethPaths();
        uint256 swapAmount = 100 * 10 ** 6;

        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(uint256(keccak256(abi.encodePacked("user", i)))));
            mintAndApproveToContract(user, address(router), usdc, weth, swapAmount, 0);
            vm.startPrank(user);
            router.swapExactTokensForTokens(swapAmount, 0, paths, user, block.timestamp);
            vm.stopPrank();
        }

        // Verify system remains stable after stress test
        DuxPair pair = DuxPair(pairUsdcWeth);
        (uint256 reserveUsdc, uint256 reserveWeth,) = pair.getReserves();
        assertTrue(reserveUsdc > 0 && reserveWeth > 0, "Reserves should remain positive after stress test");
        assertGt(pair.totalSupply(), 0, "Total supply should remain positive after stress test");

        // Verify that a final swap still works correctly
        mintAndApproveToContract(USER2, address(router), usdc, weth, swapAmount, 0);
        vm.startPrank(USER2);
        (uint256[] memory amounts,) = router.swapExactTokensForTokens(swapAmount, 0, paths, USER2, block.timestamp);
        vm.stopPrank();
        assertGt(amounts[1], 0, "Final swap should still produce output");
    }
}
