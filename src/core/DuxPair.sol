// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPoint} from "./../libraries/FixedPoint.sol";
import {IDuxPair} from "./interfaces/IDuxPair.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDuxCallee} from "./interfaces/IDuxCallee.sol";
import {Math} from "./libraries/Math.sol";

/**
 * @title DuxPair
 * @notice AMM Pair contract with LP token, liquidity management, and swap functionality.
 * @dev Supports swap fees and ratio checks on liquidity additions.
 */
contract DuxPair is ERC20, IDuxPair, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    /* ----------------------
       Custom Errors
       ---------------------- */
    error DuxPair_InsufficientLiquidityAmount(uint256 requested, uint256 available);
    error DuxPair_FactoryOnly();
    error DuxPair_AlreadyInitialized();
    error DuxPair_InvalidTokenAddress();
    error DuxPair_IdenticalAddresses();
    error DuxPair_InvalidSwapFee();
    error DuxPair_InsufficientAmountIn();
    error DuxPair_InsufficientOutput();
    error DuxPair_InvalidTo();
    error DuxPair_InsufficientLiquidity();

    error DuxPair_K(uint256 balance0Adjusted, uint256 balance1Adjusted, uint256 _r0, uint256 _r1);
    error DuxPair_LpTokenIsZero();
    error DuxPair_TotalSupplyIsZero();

    /* ==============================
       CONSTANTS / IMMUTABLES
       ============================== */
    /// @notice Minimum liquidity required to create a pair
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    /// @notice Fee denominator for swap calculations (10000 = 100%)
    uint256 public constant FEE_DENOMINATOR = 10_000;
    /// @notice Maximum swap fee in basis points (1%)
    uint16 public constant MAX_SWAP_FEE_BPS = 100;

    address private immutable FACTORY;

    /* =============================
       STATE VARIABLES
       ============================== */

    uint256 private reserve0; // Current balance of token0
    uint256 private reserve1; // Current balance of token1
    uint32 private blockTimestampLast; // Last block timestamp of reserve update

    /// @notice Token0 of the pair (sorted by address)
    address public token0;
    /// @notice Token1 of the pair (sorted by address)
    address public token1;
    /// @notice Swap fee in basis points (e.g., 30 = 0.3%)
    uint16 public swapFeeBps;
    /// @notice Pair initialization status
    bool public initialized;

    // flash loan protection parameters
    // uint256 public constant MIN_TIME_ELAPSED = 60; //60 seconds minimum between swaps, user can only swap one transation in 60 second
    // mapping(address userAddress => uint256 timestamp) private lastSwapTimestamp; // Track last swap per address
    uint256 public price0CumulativeLast; //TWAP storage
    uint256 public price1CumulativeLast; //TWAP storage
    /* ==============================
       EVENTS
       ============================== */

    event LiquidityAdded(
        address indexed sender, uint256 actualDeposit0, uint256 actualDeposit1, uint256 lpTokenMinted
    );
    event LiquidityRemoved(address indexed sender, uint256 amount0, uint256 amount1, uint256 lpTokenBurned, address indexed to);
    event Sync(uint256 reserve0, uint256 reserve1, uint256 totalSupply, uint32 timestamp);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    /* ==============================
       CONSTRUCTOR
       ============================== */

    constructor() ERC20("Dux LP Token", "DUX-LP") {
        FACTORY = msg.sender;
        address factoryOwner = Ownable(FACTORY).owner();
        _transferOwnership(factoryOwner);
    }
    /**
     * @dev Initializes the pair with token addresses and swap fee. This is low level function, please do all the check before calling
     * @param _token1 Address of the first token
     * @param _token2 Address of the second token
     * @param _swapFeeBps Basis points swap fee (e.g., 30 = 0.3%)
     */

    function initialize(address _token1, address _token2, uint16 _swapFeeBps) external onlyFactory {
        if (initialized) revert DuxPair_AlreadyInitialized();
        if (_token1 == address(0) || _token2 == address(0)) revert DuxPair_InvalidTokenAddress();
        if (_token1 == _token2) revert DuxPair_IdenticalAddresses();
        if (_swapFeeBps > MAX_SWAP_FEE_BPS) revert DuxPair_InvalidSwapFee();
        token0 = _token1;
        token1 = _token2;
        swapFeeBps = _swapFeeBps;
        initialized = true;
    }

    /* ==============================
       EXTERNAL / PUBLIC FUNCTIONS
       ============================== */

    /**
     * @notice Mint LP token for liquidity providers.
     * Lowlevel function, please do all the check before calling
     * @param to Recipient address
     * @return lpToken Amount of LP tokens minted
     */
    function mintLpToken(address to) external nonReentrant whenNotPaused returns (uint256 lpToken) {
        (uint256 _r0, uint256 _r1,) = getReserves();

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _r0;
        uint256 amount1 = balance1 - _r1;
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            // new pool
            uint256 initLiq = Math.sqrt(amount0 * amount1);
            if (initLiq <= MINIMUM_LIQUIDITY) revert DuxPair_InsufficientLiquidityAmount(MINIMUM_LIQUIDITY, initLiq);
            unchecked {
                lpToken = initLiq - MINIMUM_LIQUIDITY;
            }
            _mint(0x000000000000000000000000000000000000dEaD, MINIMUM_LIQUIDITY); // lock forever
        } else {
            // existing pool
            uint256 lp0 = uint256(amount0) * _totalSupply / _r0;
            uint256 lp1 = uint256(amount1) * _totalSupply / _r1;
            lpToken = Math.min(lp0, lp1);
        }
        if (lpToken == 0) revert DuxPair_LpTokenIsZero();
        _mint(to, lpToken);

        _syncPoolState(uint256(balance0), uint256(balance1));
        emit LiquidityAdded(to, amount0, amount1, lpToken);
    }

    /**
     * @notice Remove liquidity LP token from the pool
     * @param to Recipient address
     * @return amount0 Amount of token0 returned
     * @return amount1 Amount of token1 returned
     */
    function burnLpToken(address to) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            revert DuxPair_TotalSupplyIsZero();
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 liquidityToBurn = balanceOf(address(this));
        amount0 = (liquidityToBurn * balance0) / _totalSupply;
        amount1 = (liquidityToBurn * balance1) / _totalSupply;

        _burn(address(this), liquidityToBurn);
        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
        _syncPoolState(uint256(balance0), uint256(balance1));

        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidityToBurn, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external
        nonReentrant
        whenNotPaused
    {
        if (amount0Out == 0 && amount1Out == 0) revert DuxPair_InsufficientOutput();
        if (to == token0 || to == token1) revert DuxPair_InvalidTo();
        uint256 balance0;
        uint256 balance1;
        uint256 amount0In;
        uint256 amount1In;
        {
            uint256 _r0 = uint256(reserve0);
            uint256 _r1 = uint256(reserve1);
            uint256 _fee = uint256(swapFeeBps);

            if (amount0Out >= _r0 || amount1Out >= _r1) revert DuxPair_InsufficientLiquidity();

            if (amount0Out > 0) {
                IERC20(token0).safeTransfer(to, amount0Out);
            }
            if (amount1Out > 0) {
                IERC20(token1).safeTransfer(to, amount1Out);
            }
            if (data.length > 0) {
                require(to == msg.sender, "Dux: CALLBACK_ONLY_TO");
                IDuxCallee(to).duxCall(msg.sender, amount0Out, amount1Out, data);
            }

            balance0 = IERC20(token0).balanceOf(address(this));
            balance1 = IERC20(token1).balanceOf(address(this));
            amount0In = balance0 > _r0 - amount0Out ? balance0 - (_r0 - amount0Out) : 0;
            amount1In = balance1 > _r1 - amount1Out ? balance1 - (_r1 - amount1Out) : 0;

            if (amount0In == 0 && amount1In == 0) revert DuxPair_InsufficientAmountIn();

            unchecked {
                uint256 balance0Adjusted = balance0 * FEE_DENOMINATOR - amount0In * _fee;
                uint256 balance1Adjusted = balance1 * FEE_DENOMINATOR - amount1In * _fee;
                if (balance0Adjusted * balance1Adjusted < _r0 * _r1 * FEE_DENOMINATOR ** 2) {
                    revert DuxPair_K(balance0Adjusted, balance1Adjusted, _r0, _r1);
                }
            }
        }
        _syncPoolState(uint256(balance0), uint256(balance1));
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @notice Transfer tokens from one address to another
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param amount Amount of tokens to transfer
     * @return success Whether the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IDuxPair) returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    /* ==============================
       PRIVATE FUNCTIONS
       ============================== */
    /**
     * @notice Update reserves and TWAP prices
     * @dev Internal function to sync pool state
     * @param _newReserve0 New reserve amount of token0
     * @param _newReserve1 New reserve amount of token1
     */
    function _syncPoolState(uint256 _newReserve0, uint256 _newReserve1) internal {
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint32 blockTimestamp = uint32(block.timestamp);

        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            unchecked {
                price0CumulativeLast += uint256(FixedPoint.fraction(_reserve1, _reserve0)._x) * timeElapsed;
                price1CumulativeLast += uint256(FixedPoint.fraction(_reserve0, _reserve1)._x) * timeElapsed;
            }
        }
        reserve0 = _newReserve0;
        reserve1 = _newReserve1;
        blockTimestampLast = blockTimestamp;
        uint256 _totalSupply = totalSupply();
        emit Sync(_newReserve0, _newReserve1, _totalSupply, blockTimestamp);
    }

    /* ==============================
       VIEW / PURE FUNCTIONS
       ============================== */
    /**
     * @notice Returns current reserves and last update timestamp
     * @return _reserve0 Current reserve of token0
     * @return _reserve1 Current reserve of token1
     * @return _blockTimestampLast Last block timestamp when reserves were updated
     */
    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @notice Get the current cumulative prices for a pair
     * @return price0Cumulative The cumulative price of token0
     * @return price1Cumulative The cumulative price of token1
     * @return blockTimestamp The timestamp of the last block
     */
    function getCumulativePrices()
        public
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        price0Cumulative = price0CumulativeLast;
        price1Cumulative = price1CumulativeLast;
        blockTimestamp = blockTimestampLast;
    }

    /**
     * @notice Returns current reserves with fee
     * @return _reserve0 Current reserve of token0
     * @return _reserve1 Current reserve of token1
     * @return _fee Current swap fee in basis points
     */
    function getReservesWithFee() external view returns (uint256 _reserve0, uint256 _reserve1, uint16 _fee) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _fee = swapFeeBps;
    }

    /* ==============================
       EMERGENCY CONTROLS
       ============================== */

    /**
     * @notice Pause the contract (emergency stop)
     */
    function pause() external onlyFactory {
        _pause();
    }

    /**
     * @notice Unpause the contract (resume operations)
     */
    function unpause() external onlyFactory {
        _unpause();
    }

    /* ==============================
       MODIFIERS
    ============================== */
    // forge-lint: disable-next-line(unwrapped-modifier-logic)
    modifier onlyFactory() {
        _onlyFactory();
        _;
    }

    function _onlyFactory() internal view {
        if (msg.sender != FACTORY) revert DuxPair_FactoryOnly();
    }
}
