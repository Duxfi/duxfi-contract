// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RouterFixture} from "../shared/fixtures/RouterFixture.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";

/**
 * @title  DuxRouterTest
 * @notice Unit tests for DuxRouter contract
 */
contract DuxRouterTest is RouterFixture, LiquidityFixture {
    function setUp() public override(RouterFixture, BaseFixture) {
        RouterFixture.setUp();
    }

    /**
     * @notice Test if constructor correctly sets factory address
     */
    function testConstructor_SetupFactoryAddress() public view {
        assertEq(address(router.FACTORY()), address(factory), "Factory address should be correctly set");
    }

    /**
     * @notice Test if currentCumulativePrices function can be called successfully
     */
    function testCurrentCumulativePrices_CallSucceeds() public {
        // Ensure there is liquidity
        mintPoolUsdcWeth();
        address pair = pairUsdcWeth;

        // Get cumulative prices (don't verify values, just verify successful call)
        router.currentCumulativePrices(pair);
        // If execution reaches here, the call is successful
        assertTrue(true, "currentCumulativePrices call should succeed");
    }

    /**
     * @notice Test if getLastCumulativePrices function can be called successfully
     */
    function testGetLastCumulativePrices_CallSucceeds() public {
        // Ensure there is liquidity
        mintPoolUsdcWeth();
        address pair = pairUsdcWeth;

        // Perform a swap to update state
        mintAndApproveToContract(USER1, address(router), usdc, weth, 1000 * 10 ** 6, 0);
        vm.startPrank(USER1);
        address[] memory paths = getUsdcWethPaths();
        router.swapExactTokensForTokens(1000 * 10 ** 6, 0, paths, USER1, block.timestamp);
        vm.stopPrank();

        // Get last cumulative prices (don't verify values, just verify successful call)
        router.getLastCumulativePrices(pair);
        // If execution reaches here, the call is successful
        assertTrue(true, "getLastCumulativePrices call should succeed");
    }

    /**
     * @notice Test currentCumulativePrices function behavior with zero address
     */
    function testCurrentCumulativePrices_ZeroAddress() public {
        address zeroPair = address(0);

        // Attempt to get cumulative prices from zero address, expecting revert
        vm.expectRevert();
        router.currentCumulativePrices(zeroPair);
    }

    /**
     * @notice Test getLastCumulativePrices function behavior with zero address
     */
    function testGetLastCumulativePrices_ZeroAddress() public {
        address zeroPair = address(0);

        // Attempt to get last cumulative prices from zero address, expecting revert
        vm.expectRevert();
        router.getLastCumulativePrices(zeroPair);
    }

    /**
     * @notice Test that cumulative price functions can be called successfully for two different pairs
     */
    function testCumulativePrices_BothPairsCanBeCalled() public {
        // Create two different trading pairs
        mintPoolUsdcWeth();
        mintPoolWethDuxc();

        address pair1 = pairUsdcWeth;
        address pair2 = duxFactory.getPairByTokens(weth, duxc);

        // Get cumulative prices for both pairs to verify successful calls
        router.currentCumulativePrices(pair1);
        router.currentCumulativePrices(pair2);

        router.getLastCumulativePrices(pair1);
        router.getLastCumulativePrices(pair2);

        assertTrue(true, "All cumulative price calls should succeed");
    }
}
