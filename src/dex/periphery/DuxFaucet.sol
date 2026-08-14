// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IDuCoin {
    function mint(address to, uint256 amount) external;
}

contract DuxFaucet is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    uint256 public constant MAX_TOKENS = 50;

    /**
     * @notice Token config struct
     * @dev dailyAmount: daily amount to claim for the token
     * enabled: whether the token is enabled for claim
     */
    struct TokenConfig {
        uint256 dailyAmount;
        bool enabled;
    }

    /**
     * @notice All supported tokens
     * @dev Only used for iteration during claim
     */
    address[] public tokens;

    /**
     * @notice Token config mapping
     * @dev Key: token address
     * Value: token config
     */
    mapping(address => TokenConfig) public tokenConfigs;

    /**
     * @notice Prevent duplicated token adding
     */
    mapping(address => bool) public tokenExists;

    /**
     * @notice User last claim timestamp
     */
    mapping(address => uint256) public lastDailyClaimTime;
    /**
     * @notice Claim interval
     */
    uint256 public claimCooldown = 1 days;

    /* ==============================
       EVENTS
       ============================== */
    event TokenAdded(address indexed token, uint256 dailyAmount);
    event TokenUpdated(address indexed token, uint256 dailyAmount, bool enabled);
    event TokenClaimed(
        address indexed claimEventUser,
        uint256 claimEventTimeStamp,
        address[] claimEventTokens,
        uint256[] claimEventAmounts
    );
    event CooldownChanged(uint256 oldCooldown, uint256 newCooldown);
    event TokenRemoved(address indexed token);

    /* ==============================
       EXTERNAL / PUBLIC FUNCTIONS
       ============================== */
    /**
     * @notice Get all configured tokens
     */
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /**
     * @notice Add a token to faucet
     * @param token Token address
     * @param dailyAmount Amount user can claim each time
     */
    function addToken(address token, uint256 dailyAmount) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!tokenExists[token], "Token already exists");
        require(dailyAmount > 0, "Invalid amount");
        require(tokens.length < MAX_TOKENS, "Token limit reached");

        tokens.push(token);
        tokenExists[token] = true;
        tokenConfigs[token] = TokenConfig({dailyAmount: dailyAmount, enabled: true});
        emit TokenAdded(token, dailyAmount);
    }

    /**
     * @notice Update token config
     * @param token Token address
     * @param dailyAmount Amount user can claim each time
     * @param enabled Whether the token is enabled for claim
     */
    function updateToken(address token, uint256 dailyAmount, bool enabled) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(tokenExists[token], "Token not in list");
        tokenConfigs[token].dailyAmount = dailyAmount;
        tokenConfigs[token].enabled = enabled;
        emit TokenUpdated(token, dailyAmount, enabled);
    }

    /**
     * @notice Remove a token from faucet
     * @param token Token address
     */
    function removeToken(address token) external onlyOwner {
        require(tokenExists[token], "Token not in list");
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[length - 1];
                tokens.pop();
                break;
            }
        }
        delete tokenExists[token];
        delete tokenConfigs[token];
        emit TokenRemoved(token);
    }

    /**
     * @notice Claim all enabled tokens
     */
    function claimDaily() external nonReentrant whenNotPaused {
        require(block.timestamp - lastDailyClaimTime[msg.sender] >= claimCooldown, "Already claimed in cooldown period");
        lastDailyClaimTime[msg.sender] = block.timestamp;
        uint256 length = tokens.length;
        address[] memory claimedTokens = new address[](length);
        uint256[] memory claimedAmounts = new uint256[](length);
        uint256 count = 0;
        for (uint256 i = 0; i < length; i++) {
            address token = tokens[i];
            TokenConfig memory config = tokenConfigs[token];
            if (!config.enabled) {
                continue;
            }
            IDuCoin(token).mint(msg.sender, config.dailyAmount);

            claimedTokens[count] = token;
            claimedAmounts[count] = config.dailyAmount;
            count++;
        }

        assembly {
            mstore(claimedTokens, count)
            mstore(claimedAmounts, count)
        }
        emit TokenClaimed(msg.sender, block.timestamp, claimedTokens, claimedAmounts);
    }

    /**
     * @notice Set claim cooldown
     * @param newCooldown New cooldown in seconds
     * @dev Max cooldown is 30 days
     */
    function setCooldown(uint256 newCooldown) external onlyOwner {
        require(newCooldown <= 30 days, "Cooldown too long");
        emit CooldownChanged(claimCooldown, newCooldown);
        claimCooldown = newCooldown;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // forge-lint: disable-next-line(mixed-case-function)
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool ok,) = payable(owner()).call{value: balance}("");
        require(ok, "ETH transfer failed");
    }

    function withdrawERC20(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    receive() external payable {}
}
