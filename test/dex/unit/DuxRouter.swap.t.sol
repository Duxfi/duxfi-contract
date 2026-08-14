// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RouterFixture} from "../shared/fixtures/RouterFixture.sol";
import {BaseFixture} from "../shared/fixtures/BaseFixture.sol";
import {LiquidityFixture} from "../shared/fixtures/LiquidityFixture.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SwapLib} from "../utils/SwapLib.sol";

/**
 * @title  DuxRouterSwapTest
 * @notice Unit tests for DuxRouter contract
 */
contract DuxRouterSwapTest is RouterFixture, LiquidityFixture {
    uint256 constant SWAP_IN_USDC = 1000 * 10 ** 6;
    uint256 constant USER_EXPECTED_MIN_OUT_WETH = 0.4 * 10 ** 18;
    uint256 constant USER_EXPECTED_MAX_OUT_DAI = 0.2 * 10 ** 18;

    uint256 constant MOCK_WETH = 1 * 10 ** 18;
    uint256 constant MOCK_DUX = 1000 * 10 ** 18;

    function setUp() public override(RouterFixture, BaseFixture) {
        RouterFixture.setUp();
    }

    function testSwapExactTokensForTokens_OnePair_Success() public {
        mintPoolUsdcWeth();
        mintAndApproveToContract(USER1, address(router), usdc, weth, SWAP_IN_USDC, 0);
        vm.startPrank(USER1);
        // state before transaction
        LiquidityState memory senderStateBefore = captureState(USER1, pairUsdcWeth, usdc, weth);
        uint256 receiverBalanceBefore = IERC20(weth).balanceOf(USER2);
        //expected output should be called before swap
        (,, uint256 expectedOut,,,) = SwapLib.getExpectedSwapOutput(pairUsdcWeth, SWAP_IN_USDC, usdc);
        address[] memory paths = getUsdcWethPaths();
        (uint256[] memory amounts,) =
            router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, paths, USER2, block.timestamp);
        LiquidityState memory senderStateAfter = captureState(USER1, pairUsdcWeth, usdc, weth);
        uint256 receiverBalanceAfter = IERC20(weth).balanceOf(USER2);
        vm.stopPrank();
        assertApproxEqAbs(senderStateAfter.reserveA, senderStateBefore.reserveA + SWAP_IN_USDC, 1, "reserveA");
        assertApproxEqAbs(senderStateAfter.reserveB, senderStateBefore.reserveB - amounts[1], 1, "reserveB");
        assertGt(amounts[1], USER_EXPECTED_MIN_OUT_WETH, "amounts[1]");
        assertEq(senderStateAfter.userBalanceA, senderStateBefore.userBalanceA - SWAP_IN_USDC, "userBalanceA");
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amounts[1], "wethBalanceAfter");
        assertEq(amounts[1], expectedOut, "amounts[1] should be equal to expectedout");
    }

    function testSwapExactTokensForTokens_UsdcDai_Success() public {
        mintPoolAll();
        mintAndApproveToContract(USER1, address(router), usdc, weth, SWAP_IN_USDC, 0);
        uint256 receiverBalanceBefore = IERC20(dai).balanceOf(USER2);
        uint256 senderBalanceBefore = IERC20(usdc).balanceOf(USER1);
        address[] memory pairs = getPairsFromUsdcToDai();
        address[] memory paths = getPathsFromUsdcToDai();
        uint256[] memory expectedOuts = SwapLib.getExpectedOutPutForPairs(SWAP_IN_USDC, pairs, paths);
        // state before transaction
        LiquidityState memory stateUsdcBefore = captureState(USER1, pairUsdcWeth, usdc, weth);
        LiquidityState memory stateDaiBefore = captureState(USER2, pairBtcDai, btc, dai);
        vm.startPrank(USER1);
        (uint256[] memory amounts,) =
            router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MAX_OUT_DAI, paths, USER2, block.timestamp);
        vm.stopPrank();
        // state after transaction
        LiquidityState memory stateUsdcAfter = captureState(USER1, pairUsdcWeth, usdc, weth);
        LiquidityState memory stateDaiAfter = captureState(USER2, pairBtcDai, btc, dai);
        uint256 senderBalanceAfter = IERC20(usdc).balanceOf(USER1);
        uint256 receiverBalanceAfter = IERC20(dai).balanceOf(USER2);
        for (uint256 i = 0; i < pairs.length; i++) {
            assertEq(amounts[i + 1], expectedOuts[i], "amounts[i+1] should be equal to expectedOuts[i]");
        }
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amounts[paths.length - 1], "daiBalanceAfter");
        assertEq(senderBalanceAfter, senderBalanceBefore - SWAP_IN_USDC, "usdcBalanceAfter");
        assertEq(stateUsdcAfter.reserveA, stateUsdcBefore.reserveA + SWAP_IN_USDC, "reserveA");
        assertEq(stateUsdcAfter.reserveB, stateUsdcBefore.reserveB - amounts[1], "reserveB");
        assertEq(stateDaiAfter.reserveA, stateDaiBefore.reserveA + amounts[paths.length - 2], "reserveA");
        assertEq(stateDaiAfter.reserveB, stateDaiBefore.reserveB - amounts[paths.length - 1], "reserveB");
    }

    function testSwapExactTokensForTokens_OnePair_InsufficientLiquidity_ExpectedRevert() public {
        vm.startPrank(USER1);
        address[] memory paths = getUsdcWethPaths();
        vm.expectRevert(abi.encodeWithSignature("DuxRouter_InsufficientLiquidity()"));
        router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, paths, USER1, block.timestamp);
    }

    function testSwapExactTokensForTokens_PathTooLong_ExpectedRevert() public {
        address[] memory pathsTooLong = getMaxPaths();
        vm.expectRevert(abi.encodeWithSignature("DuxRouter_PathToLong()"));
        router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, pathsTooLong, USER1, block.timestamp);
    }

    function testSwapExactTokensForTokens_ToZeroAddress_ExpectedRevert() public {
        address[] memory paths = getUsdcWethPaths();
        vm.expectRevert(abi.encodeWithSignature("DuxRouter_ZeroAddress()"));
        router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, paths, address(0), block.timestamp);
    }

    function testSwapExactTokensForTokens_AmountInZero_ExpectedRevert() public {
        address[] memory paths = getUsdcWethPaths();
        vm.expectRevert(abi.encodeWithSignature("DuxRouter_ZeroAmount()"));
        router.swapExactTokensForTokens(0, USER_EXPECTED_MIN_OUT_WETH, paths, USER1, block.timestamp);
    }

    function testSwapExactTokensForTokens_NotMeetExpectedMinOut_ExpectedRevert() public {
        mintPoolUsdcWeth();
        (,, uint256 expectedOutput,,,) = SwapLib.getExpectedSwapOutput(pairUsdcWeth, SWAP_IN_USDC, usdc);
        uint256 higherExpectedMinOut = expectedOutput + 1;
        vm.startPrank(USER1);
        mintAndApproveToContract(USER1, address(router), usdc, weth, SWAP_IN_USDC, 0);
        address[] memory paths = getUsdcWethPaths();
        vm.expectRevert(abi.encodeWithSignature("DuxRouter_DoesNotMeetUserExpectedMinOut()"));
        router.swapExactTokensForTokens(SWAP_IN_USDC, higherExpectedMinOut, paths, USER2, block.timestamp);
        vm.stopPrank();
    }

    function testSwapExactTokensForTokens_ExpiredDeadline_ExpectedRevert() public {
        mintPoolUsdcWeth();
        mintAndApproveToContract(USER1, address(router), usdc, weth, SWAP_IN_USDC, 0);
        address[] memory paths = getUsdcWethPaths();
        vm.expectRevert(abi.encodeWithSignature("DuxRouter_Expired()"));
        router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, paths, USER2, block.timestamp - 1);
    }

    function testSwapExactTokensForTokens_WethToUsdc_Success() public {
        mintPoolUsdcWeth();
        uint256 swapInWeth = MOCK_WETH;
        mintAndApproveToContract(USER1, address(router), weth, usdc, swapInWeth, 0);
        uint256 receiverBalanceBefore = IERC20(usdc).balanceOf(USER2);
        (,, uint256 expectedOut,,,) = SwapLib.getExpectedSwapOutput(pairUsdcWeth, swapInWeth, weth);
        address[] memory paths = new address[](2);
        paths[0] = weth;
        paths[1] = usdc;
        vm.startPrank(USER1);
        (uint256[] memory amounts,) = router.swapExactTokensForTokens(swapInWeth, 0, paths, USER2, block.timestamp);
        vm.stopPrank();
        uint256 receiverBalanceAfter = IERC20(usdc).balanceOf(USER2);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amounts[1], "usdcBalanceAfter");
        assertEq(amounts[1], expectedOut, "amounts[1] should be equal to expectedout");
    }

    function testSwapExactTokensForTokens_TwoHops_Success() public {
        mintPoolUsdcWeth();
        mintPoolWethDuxc();
        mintAndApproveToContract(USER1, address(router), usdc, duxc, SWAP_IN_USDC, 0);
        uint256 receiverBalanceBefore = IERC20(duxc).balanceOf(USER2);
        address[] memory pairs = getPairsUsdcWethDuxPaths();
        address[] memory paths = getUsdcWethDuxPaths();
        uint256[] memory expectedOuts = SwapLib.getExpectedOutPutForPairs(SWAP_IN_USDC, pairs, paths);
        vm.startPrank(USER1);
        (uint256[] memory amounts,) = router.swapExactTokensForTokens(SWAP_IN_USDC, 0, paths, USER2, block.timestamp);
        vm.stopPrank();
        uint256 receiverBalanceAfter = IERC20(duxc).balanceOf(USER2);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amounts[2], "duxcBalanceAfter");
        for (uint256 i = 0; i < pairs.length; i++) {
            assertEq(amounts[i + 1], expectedOuts[i], "amounts[i+1] should be equal to expectedOuts[i]");
        }
    }

    function testSwapExactTokensForTokens_PathWithZeroAddress_ExpectedRevert() public {
        address[] memory pathsWithZero = new address[](3);
        pathsWithZero[0] = usdc;
        pathsWithZero[1] = address(0);
        pathsWithZero[2] = weth;
        vm.expectRevert();
        router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, pathsWithZero, USER1, block.timestamp);
    }

    function testSwapExactTokensForTokens_InvalidPairPath_ExpectedRevert() public {
        address[] memory invalidPaths = new address[](3);
        invalidPaths[0] = usdc;
        invalidPaths[1] = mockToken;
        invalidPaths[2] = weth;
        vm.expectRevert();
        router.swapExactTokensForTokens(SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, invalidPaths, USER1, block.timestamp);
    }

    function testSwapExactTokensForTokens_SmallAmount_Success() public {
        mintPoolUsdcWeth();
        uint256 smallAmount = 100 * 10 ** 6; // 100 USDC
        mintAndApproveToContract(USER1, address(router), usdc, weth, smallAmount, 0);
        (,, uint256 expectedOut,,,) = SwapLib.getExpectedSwapOutput(pairUsdcWeth, smallAmount, usdc);
        address[] memory paths = getUsdcWethPaths();
        vm.startPrank(USER1);
        (uint256[] memory amounts,) = router.swapExactTokensForTokens(smallAmount, 0, paths, USER2, block.timestamp);
        vm.stopPrank();
        assertEq(amounts[1], expectedOut, "amounts[1] should be equal to expectedout");
    }

    function testSwapExactTokensForTokens_SameInputOutputToken_ExpectedRevert() public {
        address[] memory sameTokenPaths = new address[](2);
        sameTokenPaths[0] = usdc;
        sameTokenPaths[1] = usdc;
        vm.expectRevert();
        router.swapExactTokensForTokens(
            SWAP_IN_USDC, USER_EXPECTED_MIN_OUT_WETH, sameTokenPaths, USER1, block.timestamp
        );
    }
}
