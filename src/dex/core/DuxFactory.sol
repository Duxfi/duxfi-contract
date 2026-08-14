// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DuxPair} from "./DuxPair.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDuxFactory} from "./interfaces/IDuxFactory.sol";
import {IDuxPair} from "./interfaces/IDuxPair.sol";

/**
 * @title DuxFactory
 * @notice Factory contract to deploy DuxPair instances.
 * @dev Follows production-level best practices with Ownable access control.
 */
contract DuxFactory is Ownable, IDuxFactory {
    /* ----------------------
    Custom Errors
    ---------------------- */
    error DuxFactory_PairAlreadyExists();
    error DuxFactory_InvalidTokenAddress();
    error DuxFactory_IdenticalAddresses();
    error DuxFactory_InvalidSwapFee();
    error DuxFactory_CreateFailed();
    error DuxFactory_TokenNotFound();

    /* ==============================
       CONSTANTS / IMMUTABLES
       ============================== */
    /// @notice Maximum swap fee in basis points (example: 1%)

    uint16 public constant MAX_SWAP_FEE_BPS = 100;

    /// @notice Mapping from token pair hash to DuxPair address
    mapping(address token0 => mapping(address token1 => address pair)) public getPair;
    /// @notice Array of all deployed pairs
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, address creator);

    /**
     * @notice Create a new DuxPair instance, max swap fee is 1%
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @param swapFeeBps Swap fee in basis points (example: 30 = 0.3%)
     * @param creator Address of the creator
     * @return pair Address of the created DuxPair
     */
    function createPair(address tokenA, address tokenB, uint16 swapFeeBps, address creator) external returns (address pair) {
        if (tokenA == address(0) || tokenB == address(0)) {
            revert DuxFactory_InvalidTokenAddress();
        }
        if (tokenA == tokenB) revert DuxFactory_IdenticalAddresses();
        if (swapFeeBps > MAX_SWAP_FEE_BPS) revert DuxFactory_InvalidSwapFee();
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (getPair[token0][token1] != address(0)) revert DuxFactory_PairAlreadyExists();

        bytes memory bytecode = type(DuxPair).creationCode;
        bytes32 salt = _efficientHash(token0, token1);
        // create pair contract
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        if (pair == address(0)) revert DuxFactory_CreateFailed();
        IDuxPair(pair).initialize(token0, token1, swapFeeBps);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // bidirectional
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, creator);
    }

    /**
     * @notice Pause specific pair
     * @param tokenA First token address
     * @param tokenB Second token address
     */
    function pausePair(address tokenA, address tokenB) external onlyOwner {
        address pair = getPair[tokenA][tokenB];
        IDuxPair(pair).pause();
    }

    /**
     * @notice Unpause specific pair
     * @param tokenA First token address
     * @param tokenB Second token address
     */
    function unpausePair(address tokenA, address tokenB) external onlyOwner {
        address pair = getPair[tokenA][tokenB];
        IDuxPair(pair).unpause();
    }

    /**
     * @notice Pause all pairs
     */
    function pauseAllPairs() external onlyOwner {
        uint256 length = allPairs.length;
        for (uint256 i; i < length;) {
            IDuxPair(allPairs[i]).pause();
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Unpause all pairs
     */
    function unpauseAllPairs() external onlyOwner {
        uint256 length = allPairs.length;
        for (uint256 i; i < length;) {
            IDuxPair(allPairs[i]).unpause();
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Returns number of all deployed pairs
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function getPairByTokens(address tokenA, address tokenB) external view returns (address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pair = getPair[token0][token1];
        if (pair == address(0)) {
            revert DuxFactory_TokenNotFound();
        }
    }

    /**
     * @notice Check if a pair exists for given tokens
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return exists Whether the pair exists
     * @return pair Address of the pair (if exists)
     */
    function pairExists(address tokenA, address tokenB) external view returns (bool exists, address pair) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        pair = getPair[token0][token1];
        exists = pair != address(0);
    }

    function getAllPairs() external view returns (address[] memory) {
        return allPairs;
    }

    /* ==============================
       INTERNAL FUNCTIONS
       ============================== */

    /**
     * @notice Efficiently hash two token addresses for use as CREATE2 salt
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return hash Keccak256 hash of the packed token addresses
     */
    function _efficientHash(address tokenA, address tokenB) internal pure returns (bytes32 hash) {
        assembly {
            // Store the two addresses in memory
            mstore(0x00, tokenA)
            mstore(0x20, tokenB)
            // Hash the two addresses directly
            hash := keccak256(0x00, 0x40)
        }
    }

    /**
     * @notice Sort two token addresses deterministically
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return token0 Lower address
     * @return token1 Higher address
     */
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}
