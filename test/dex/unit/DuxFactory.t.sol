// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DuxFactory} from "@dex/core/DuxFactory.sol";
import {DuxPair} from "@dex/core/DuxPair.sol";
import {MockERC} from "../mocks/MockERC.sol";

/**
 * @title DuxFactoryTest
 * @notice Unit tests for DuxFactory contract
 */
contract DuxFactoryTest is Test {
    DuxFactory public factory;
    MockERC public tokenA;
    MockERC public tokenB;
    MockERC public tokenC;

    address public owner = address(this);
    address public nonOwner = address(0x1234);

    function setUp() public {
        factory = new DuxFactory();
        tokenA = new MockERC("TokenA", "TKA", 18);
        tokenB = new MockERC("TokenB", "TKB", 18);
        tokenC = new MockERC("TokenC", "TKC", 6);
    }

    /* =============================
       CREATE PAIR TESTS
       ============================= */

    function testCreatePair_Success() public {
        address pairUsdcWeth = factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        assertTrue(pairUsdcWeth != address(0));
        assertEq(factory.allPairsLength(), 1);

        (bool exists, address pair) = factory.pairExists(address(tokenA), address(tokenB));
        assertTrue(exists);
        assertEq(pair, pairUsdcWeth);
    }

    function testCreatePair_IdenticalAddresses_Reverts() public {
        vm.expectRevert(DuxFactory.DuxFactory_IdenticalAddresses.selector);
        factory.createPair(address(tokenA), address(tokenA), 30, address(this));
    }

    function testCreatePair_ZeroAddress_Reverts() public {
        vm.expectRevert(DuxFactory.DuxFactory_InvalidTokenAddress.selector);
        factory.createPair(address(0), address(tokenB), 30, address(this));

        vm.expectRevert(DuxFactory.DuxFactory_InvalidTokenAddress.selector);
        factory.createPair(address(tokenA), address(0), 30, address(this));
    }

    function testCreatePair_InvalidSwapFee_Reverts() public {
        vm.expectRevert(DuxFactory.DuxFactory_InvalidSwapFee.selector);
        factory.createPair(address(tokenA), address(tokenB), 101, address(this));
    }

    function testCreatePair_Duplicate_Reverts() public {
        factory.createPair(address(tokenA), address(tokenB), 30, address(this));

        vm.expectRevert(DuxFactory.DuxFactory_PairAlreadyExists.selector);
        factory.createPair(address(tokenA), address(tokenB), 30, address(this));
    }

    function testCreatePair_NonOwner_OwnerIsFactory() public {
        vm.prank(nonOwner);
        address pairAddress = factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        DuxPair pair = DuxPair(pairAddress);
        assertEq(pair.owner(), factory.owner());
    }

    /* =============================
       PAUSE/UNPAUSE TESTS
       ============================= */

    function testPausePair_Success() public {
        address pairUsdcWeth = factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        factory.pausePair(address(tokenA), address(tokenB));

        DuxPair pair = DuxPair(pairUsdcWeth);
        assertTrue(pair.paused());
    }

    function testPausePair_NonOwner_Reverts() public {
        factory.createPair(address(tokenA), address(tokenB), 30, address(this));

        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.pausePair(address(tokenA), address(tokenB));
    }

    function testUnpausePair_Success() public {
        address pairUsdcWeth = factory.createPair(address(tokenA), address(tokenB), 30, address(this));

        factory.pausePair(address(tokenA), address(tokenB));
        factory.unpausePair(address(tokenA), address(tokenB));

        DuxPair pair = DuxPair(pairUsdcWeth);
        assertFalse(pair.paused());
    }

    /* =============================
       PAUSE/UNPAUSE ALL PAIRS TESTS
       ============================= */

    function testPauseAllPairs_Success() public {
        // Create multiple pairs
        address pair1 = factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        address pair2 = factory.createPair(address(tokenA), address(tokenC), 30, address(this));

        // Pause all pairs
        factory.pauseAllPairs();

        // Verify both pairs are paused
        assertTrue(DuxPair(pair1).paused());
        assertTrue(DuxPair(pair2).paused());
    }

    function testPauseAllPairs_NonOwner_Reverts() public {
        factory.createPair(address(tokenA), address(tokenB), 30, address(this));

        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.pauseAllPairs();
    }

    function testUnpauseAllPairs_Success() public {
        // Create multiple pairs
        address pair1 = factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        address pair2 = factory.createPair(address(tokenA), address(tokenC), 30, address(this));

        // First pause all
        factory.pauseAllPairs();
        assertTrue(DuxPair(pair1).paused());
        assertTrue(DuxPair(pair2).paused());

        // Then unpause all
        factory.unpauseAllPairs();

        // Verify both pairs are unpaused
        assertFalse(DuxPair(pair1).paused());
        assertFalse(DuxPair(pair2).paused());
    }

    function testUnpauseAllPairs_NonOwner_Reverts() public {
        factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        factory.pauseAllPairs();

        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.unpauseAllPairs();
    }

    /* =============================
       VIEW FUNCTION TESTS
       ============================= */

    function testAllPairsLength() public {
        assertEq(factory.allPairsLength(), 0);
        factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        assertEq(factory.allPairsLength(), 1);
    }

    function testPairExists() public {
        (bool exists,) = factory.pairExists(address(tokenA), address(tokenB));
        assertFalse(exists);

        factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        (exists,) = factory.pairExists(address(tokenA), address(tokenB));
        assertTrue(exists);
    }

    function testGetPairMapping() public {
        address pairUsdcWeth = factory.createPair(address(tokenA), address(tokenB), 30, address(this));

        assertEq(factory.getPair(address(tokenA), address(tokenB)), pairUsdcWeth);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pairUsdcWeth);
    }

    function testTokenSorting() public {
        address pairUsdcWeth = factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        DuxPair pair = DuxPair(pairUsdcWeth);

        (address token0, address token1) =
            address(tokenA) < address(tokenB) ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));

        assertEq(pair.token0(), token0);
        assertEq(pair.token1(), token1);
    }

    function testGetAllPairs() public {
        address pairUsdcWeth = factory.createPair(address(tokenA), address(tokenB), 30, address(this));
        address[] memory pairs = factory.getAllPairs();
        assertEq(pairs.length, 1);
        assertEq(pairs[0], pairUsdcWeth);
    }
}
