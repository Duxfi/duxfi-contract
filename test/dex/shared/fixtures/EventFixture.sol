// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import {Test} from "forge-std/Test.sol";

contract EventFixture is Test {
    /* ==============================
       Event Helper
       ============================== */

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    function expectSwapEvent(
        address contractAddress,
        address sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) internal {
        vm.expectEmit(true, true, false, true, contractAddress);
        emit Swap(sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    event Sync(uint256 reserve0, uint256 reserve1, uint256 totalSupply, uint32 timestamp);

    function expectSyncEvent(address contractAddress, uint256 reserve0, uint256 reserve1, uint256 totalSupply, uint32 timestamp) internal {
        vm.expectEmit(true, true, false, false, contractAddress);
        emit Sync(reserve0, reserve1, totalSupply, timestamp);
    }

    event LiquidityAdded(
        address indexed sender, uint256 actualDeposit0, uint256 actualDeposit1, uint256 lpTokenMinted
    );

    function expectLiquidityAddedEvent(
        address contractAddress,
        address sender,
        uint256 actualDeposit0,
        uint256 actualDeposit1,
        uint256 lpTokenMinted
    ) internal {
        vm.expectEmit(true, false, false, true, contractAddress);
        emit LiquidityAdded(sender, actualDeposit0, actualDeposit1, lpTokenMinted);
    }

    event LiquidityRemoved(address indexed sender, uint256 amount0, uint256 amount1, uint256 lpTokenBurned, address indexed to);

    function expectLiquidityRemovedEvent(
        address contractAddress,
        address sender,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokenBurned,
        address to
    ) internal {
        vm.expectEmit(true, false, false, true, contractAddress);
        emit LiquidityRemoved(sender, amount0, amount1, lpTokenBurned, to);
    }
}
