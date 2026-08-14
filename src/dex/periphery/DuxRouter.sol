// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDuxFactory} from "./../core/interfaces/IDuxFactory.sol";
import {DuxLibrary} from "./libraries/DuxLibrary.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDuxPair} from "./../core/interfaces/IDuxPair.sol";
import {DuxTWAPOracleLibrary} from "./libraries/DuxTWAPOracleLibrary.sol";
import {IDuxRouter} from "./../periphery/interfaces/IDuxRouter.sol";

/**
 * @title DuxPair
 * @notice AMM Pair contract with LP token, liquidity management, and swap functionality.
 * @dev Supports swap fees and ratio checks on liquidity additions.
 */
contract DuxRouter is ReentrancyGuard, IDuxRouter {
    using SafeERC20 for IERC20;

    /* ----------------------
       Custom Errors
       ---------------------- */
    error DuxRouter_ZeroAmount();
    error DuxRouter_ZeroAddress();
    error DuxRouter_InsufficientLiquidityAmount(uint256 lpToken, uint256 totalSupply);
    error DuxRouter_InsufficientInput();
    error DuxRouter_InsufficientLiquidity();
    error DuxRouter_DoesNotMeetUserExpectedMinOut();
    error DuxRouter_Expired();
    error DuxRouter_PathToLong();
    error DuxRouter_UnknownToken();

    /* ==============================
       CONSTANTS / IMMUTABLES
       ============================== */
    address public immutable FACTORY;

    /* ==============================
       MODIFIERS
       ============================== */
    /**
     * @dev Ensure transaction is not expired
     * @notice Deadline should be based on blockchain time, not real-world time
     */
    modifier ensure(uint256 deadline) {
        _ensure(deadline);
        _;
    }

    /**
     * @dev Internal function to ensure transaction is not expired
     * @notice Deadline should be based on blockchain time, not real-world time
     */
    function _ensure(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DuxRouter_Expired();
    }

    /* ==============================
       EXTERNAL / PUBLIC FUNCTIONS
       ============================== */
    constructor(address _factory) {
        FACTORY = _factory;
    }

    /**
     * @notice Add liquidity to a DuxPair,
     * @dev Deposits tokens into a DuxPair contract, minting LP tokens in return.
     * When user provides imbalanced amounts:
     * 1. Calculates the optimal amount based on pool ratio - k value
     * 2. Returns adjusted amounts that maintain pool price integrity
     * 3. Excess tokens are simply not used (handled by frontend or user)
     * @param tokenA Address of tokenA
     * @param amountA Desired amount of tokenA
     * @param tokenB Address of tokenB
     * @param amountB Desired amount of tokenB
     * @return actualDepositeTokenA Actual amount of tokenA deposited
     * @return actualDepositeTokenB Actual amount of tokenB deposited
     * @return lpToken Amount of LP tokens minted
     */
    function addLiquidity(address tokenA, uint256 amountA, address tokenB, uint256 amountB)
        external
        nonReentrant
        returns (uint256 actualDepositeTokenA, uint256 actualDepositeTokenB, uint256 lpToken)
    {
        if (amountA == 0 || amountB == 0) revert DuxRouter_ZeroAmount();
        if (tokenA == address(0) || tokenB == address(0)) revert DuxRouter_ZeroAddress();

        (address token0, address token1) = DuxLibrary.sortTokens(tokenA, tokenB);
        address pair = IDuxFactory(FACTORY).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            // create the pair if not exist
            pair = IDuxFactory(FACTORY).createPair(tokenA, tokenB, 30,msg.sender);
        }
        IDuxPair _duxPair = IDuxPair(pair);
        (uint256 deposite0, uint256 deposite1) = _sortTokenAndCalculateOptimalLiquidity(tokenA, amountA, amountB, pair);

        IERC20(token0).safeTransferFrom(msg.sender, pair, deposite0);
        IERC20(token1).safeTransferFrom(msg.sender, pair, deposite1);
        lpToken = _duxPair.mintLpToken(msg.sender);
        if (tokenA == token0) {
            actualDepositeTokenA = deposite0;
            actualDepositeTokenB = deposite1;
        } else {
            actualDepositeTokenA = deposite1;
            actualDepositeTokenB = deposite0;
        }
    }

    /**
     * @notice Remove liquidity LP token from the pool
     * @param tokenA Address of tokenA
     * @param tokenB Address of tokenB
     * @param lpToken Amount of LP tokens to burn
     * @param to Recipient address
     * @return amountTokenA Amount of tokenA returned
     * @return amountTokenB Amount of tokenB returned
     */
    function removeLiquidity(address tokenA, address tokenB, uint256 lpToken, address to)
        external
        nonReentrant
        returns (uint256 amountTokenA, uint256 amountTokenB)
    {
        if (lpToken == 0) revert DuxRouter_InsufficientLiquidityAmount(lpToken, 0);
        if (to == address(0)) revert DuxRouter_ZeroAddress();
        address pair = DuxLibrary.getPairRevertByNotExistPair(FACTORY, tokenA, tokenB);
        IDuxPair _duxPair = IDuxPair(pair);
        bool success = _duxPair.transferFrom(msg.sender, pair, lpToken);
        require(success, "TRANSFER_FROM_FAILED");
        (uint256 amount0, uint256 amount1) = _duxPair.burnLpToken(to);
        if (tokenA == _duxPair.token0()) {
            amountTokenA = amount0;
            amountTokenB = amount1;
        } else {
            amountTokenA = amount1;
            amountTokenB = amount0;
        }
    }

    /**
     * @notice Swap tokens for tokens, support multiple paths, e.g., 99 USDT->1 ETH ->200 DUX, max paths 5
     * @param amountIn The amount of input token in the swap, e.g. 99 USDT
     * @param userExpecrtedMinOut The minimum amount of output token to receive, e.g. 200 DUX
     * @param paths The array of token addresses in the swap path (maxlength 5), must be in the right orders
     * @param to The recipient address
     * @param deadline The deadline timestamp for the swap based on block chain block.timestamp not time in real world
     * @return amountOuts The array of output amounts for each hop, start with amountIn, e.g. [99 USDT, 1 ETH, 200 DUX]
     * @return pairs The array of pair addresses for each hop, e.g. [USDT-ETH, ETH-DUX]
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 userExpecrtedMinOut,
        address[] calldata paths,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amountOuts, address[] memory pairs) {
        if (paths.length > 5) revert DuxRouter_PathToLong();
        if (to == address(0)) revert DuxRouter_ZeroAddress();
        if (amountIn == 0) revert DuxRouter_ZeroAmount();

        (amountOuts, pairs) = _getAmountsOut(amountIn, paths);
        // check the output amount is greater than or equal to userExpecrtedMinOut
        if (amountOuts[amountOuts.length - 1] < userExpecrtedMinOut) {
            revert DuxRouter_DoesNotMeetUserExpectedMinOut();
        }

        // Transfer input token
        IERC20(paths[0]).safeTransferFrom(msg.sender, pairs[0], amountOuts[0]);
        _swap(amountOuts, paths, to, pairs);
    }

    /**
     * @notice calculate the current cumulative prices for a pair
     * @param pair The address of the pair
     * @return price0Cumulative The cumulative price of token0
     * @return price1Cumulative The cumulative price of token1
     * @return blockTimestamp The timestamp of the last block
     */
    function currentCumulativePrices(address pair)
        public
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        (price0Cumulative, price1Cumulative, blockTimestamp) = DuxTWAPOracleLibrary.currentCumulativePrices(pair);
    }

    /**
     * @notice Get the last cumulative prices for a pair
     * @param pair The address of the pair
     * @return price0Cumulative The cumulative price of token0
     * @return price1Cumulative The cumulative price of token1
     * @return blockTimestamp The timestamp of the last block
     */
    function getLastCumulativePrices(address pair)
        public
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        (price0Cumulative, price1Cumulative, blockTimestamp) = IDuxPair(pair).getCumulativePrices();
    }

    /* ==============================
       INTERNAL FUNCTIONS
       ============================== */

    /**
     * @notice Calculate optimal liquidity amounts based on pool ratio
     * @dev Implements Uniswap V2 style handling - automatically adjusts user amounts
     * to match current pool ratio and returns optimal deposit amounts
     *
     * When user provides imbalanced amounts, this function:
     * 1. Calculates the optimal amount based on pool ratio - k value
     * 2. Returns adjusted amounts that maintain pool price integrity
     * 3. Excess tokens are simply not used (handled by frontend or user)
     * @dev Ensures token0 is always the token with lower address
     * @param tokenA Address of tokenA
     * @param amountA Desired amount of tokenA
     * @param amountB Desired amount of tokenB
     * @param pair DuxPair contract address
     * @return shouldDeposite0 Optimal amount of token0 to deposit
     * @return shouldDeposite1 Optimal amount of token1 to deposit
     */
    function _sortTokenAndCalculateOptimalLiquidity(address tokenA, uint256 amountA, uint256 amountB, address pair)
        private
        view
        returns (uint256 shouldDeposite0, uint256 shouldDeposite1)
    {
        IDuxPair _duxPair = IDuxPair(pair);
        (uint256 _r0, uint256 _r1,) = _duxPair.getReserves();
        uint256 amount0Desired;
        uint256 amount1Desired;
        if (tokenA == _duxPair.token0()) {
            amount0Desired = amountA;
            amount1Desired = amountB;
        } else if (tokenA == _duxPair.token1()) {
            amount0Desired = amountB;
            amount1Desired = amountA;
        } else {
            revert DuxRouter_UnknownToken();
        }

        if (_r0 == 0 && _r1 == 0) {
            // New pool, accept any ratio (initial liquidity addition)
            return (amount0Desired, amount1Desired);
        }
        uint256 amount1Optimal = (amount0Desired * _r1) / _r0;
        uint256 amount0Optimal = (amount1Desired * _r0) / _r1;
        if (amount1Optimal <= amount1Desired) {
            // get optimal value base on token0 Use token0 as base, token1 has surplus
            shouldDeposite0 = amount0Desired;
            shouldDeposite1 = amount1Optimal;
        } else {
            // Use token1 as base, token0 has surplus
            shouldDeposite0 = amount0Optimal;
            shouldDeposite1 = amount1Desired;
        }
        require(shouldDeposite0 != 0 && shouldDeposite1 != 0, "Invalid desired amounts ratio");
    }

    /**
     * @notice Execute a multi-hop swap
     * @param amountOuts The array of output amounts for each hop
     * @param path The array of token addresses in the swap path
     * @param _to The recipient address
     * @param pairs The array of pair addresses for each hop
     */

    function _swap(uint256[] memory amountOuts, address[] memory path, address _to, address[] memory pairs) private {
        uint256 pathLength = path.length;

        unchecked {
            for (uint256 i; i < pathLength - 1; ++i) {
                //  address input = path[i];
                //   address output = path[i + 1];
                (address token0,) = DuxLibrary.sortTokens(path[i], path[i + 1]);
                uint256 amountOut = amountOuts[i + 1];
                uint256 amount0Out;
                uint256 amount1Out;
                if (path[i] == token0) {
                    amount0Out = 0;
                    amount1Out = amountOut;
                } else {
                    amount0Out = amountOut;
                    amount1Out = 0;
                }
                address recipient = i < pathLength - 2 ? pairs[i + 1] : _to;
                IDuxPair(pairs[i]).swap(amount0Out, amount1Out, recipient, "");
            }
        }
    }

    /**
     * @notice Calculate the output amounts for a multi-hop swap, e.g.  USDT ->  ETH -> DUX
     * @param amountIn The amount of input token in the swap, e.g. 99 USDT
     * @param paths The array of token addresses in the swap path, e.g. [USDT, ETH, DUX]
     * @return amountOuts The array of output amounts for each hop, e.g. [99 USDT, 1 ETH, 200 DUX]
     * @return pairs The array of pair addresses for each hop, e.g. [USDT-ETH, ETH-DUX]
     */
    function _getAmountsOut(uint256 amountIn, address[] memory paths)
        private
        view
        returns (uint256[] memory amountOuts, address[] memory pairs)
    {
        uint256 pathLength = paths.length;
        amountOuts = new uint256[](pathLength);
        pairs = new address[](pathLength - 1);
        amountOuts[0] = amountIn;
        for (uint256 i; i < pathLength - 1;) {
            (uint256 reserveIn, uint256 reserveOut, uint16 feeBps, address pair) =
            DuxLibrary.getPairsReservesAndFee(FACTORY, paths[i], paths[i + 1]);
            amountOuts[i + 1] = _getAmountOut(amountOuts[i], reserveIn, reserveOut, feeBps);
            pairs[i] = pair;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculate the output amount for a swap
     * @param amountIn The amount of input tokens
     * @param reserveIn The reserve of input token
     * @param reserveOut The reserve of output token
     * @param feeBps The swap fee in basis points
     * @return amountOut The amount of output tokens
     */
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint16 feeBps)
        private
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert DuxRouter_InsufficientInput();
        if (reserveIn == 0 || reserveOut == 0) revert DuxRouter_InsufficientLiquidity();
        uint256 amountInAfterFee = amountIn * (10_000 - feeBps);
        // keep constant of k = reserveIn × reserveOut
        amountOut = (amountInAfterFee * reserveOut) / (reserveIn * 10_000 + amountInAfterFee);
    }
}
