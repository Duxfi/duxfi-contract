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

    // MAX_TOKENS allowed in the faucet
    uint256 public constant MAX_TOKENS = 50;

    address[] public tokens;
    uint256 public claimCooldown = 1 days;
    mapping(address => uint256) public dailyAmounts;
    mapping(address => uint256) public lastDailyClaimTime;

    event TokenClaimed(
        address indexed claimEventUser,
        uint256 claimEventTimeStamp,
        address[] claimEventTokens,
        uint256[] claimEventAmounts
    );
    event CooldownChanged(uint256 oldCooldown, uint256 newCooldown);
    event TokenSet(address indexed token, uint256 amount, bool enabled);
    event TokenRemoved(address indexed token);
    event AllTokensCleared();

    constructor() Ownable() {}

    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /**
     * @notice add tokens to faucet
     */
    function setTokens(address[] calldata _tokens, uint256[] calldata _dailyAmounts) external onlyOwner {
        require(_tokens.length == _dailyAmounts.length, "Array length mismatch");

        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            uint256 amt = _dailyAmounts[i];
            require(token != address(0), "Invalid token address");
            require(tokens.length < MAX_TOKENS, "Token list full");
            tokens.push(token);
            dailyAmounts[token] = amt;

            emit TokenSet(token, amt, amt > 0);
        }
    }

    /**
     * @notice remove token from faucet
     * @param _token token address
     */
    function removeToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        delete dailyAmounts[_token];
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (tokens[i] == _token) {
                tokens[i] = tokens[len - 1];
                tokens.pop();
                break;
            }
        }

        emit TokenRemoved(_token);
    }

    /**
     * @notice update daily amount for a token
     * @param _token token address
     * @param _newAmount new daily amount
     */
    function updateTokenAmount(address _token, uint256 _newAmount) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        require(dailyAmounts[_token] > 0 || _isInTokenList(_token), "Token not in list");
        dailyAmounts[_token] = _newAmount;
        emit TokenSet(_token, _newAmount, _newAmount > 0);
    }

    /**
     * @notice check if token is in the list
     * @param _token token address
     * @return true if token is in the list
     */
    function _isInTokenList(address _token) internal view returns (bool) {
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (tokens[i] == _token) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice clear all tokens from faucet
     */
    function clearAllTokens() external onlyOwner {
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            address token = tokens[i];
            delete dailyAmounts[token];
        }
        delete tokens;

        emit AllTokensCleared();
    }

    /**
     * @notice set claim cooldown period
     */
    function setCooldown(uint256 _newCooldown) external onlyOwner {
        require(_newCooldown <= 30 days, "Cooldown too long");
        emit CooldownChanged(claimCooldown, _newCooldown);
        claimCooldown = _newCooldown;
    }

    /**
     * @notice claim all enabled tokens
     */
    function claimDaily() external nonReentrant whenNotPaused {
        require(block.timestamp - lastDailyClaimTime[msg.sender] >= claimCooldown, "Already claimed in cooldown period");

        uint256 tokenCount = tokens.length;
        uint256[] memory amounts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            address token = tokens[i];
            uint256 amt = dailyAmounts[token];
            if (amt > 0) {
                amounts[i] = amt;
                IDuCoin(token).mint(msg.sender, amt);
            }
        }

        lastDailyClaimTime[msg.sender] = block.timestamp;
        emit TokenClaimed(msg.sender, block.timestamp, tokens, amounts);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

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
