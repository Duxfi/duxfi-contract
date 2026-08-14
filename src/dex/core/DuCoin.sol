// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DuCoin is ERC20, Ownable {
    uint8 private immutable DECIMALS;

    // Minter role management
    mapping(address => bool) public minters;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        DECIMALS = decimals_;
        // Deployer automatically becomes a minter
        minters[msg.sender] = true;
        emit MinterAdded(msg.sender);
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    modifier onlyMinter() {
        _onlyMinter();
        _;
    }

    function _onlyMinter() internal view {
        require(minters[msg.sender], "DuCoin: caller is not minter");
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "DuCoin: minter is zero address");
        require(!minters[minter], "DuCoin: minter already exists");
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        require(minters[minter], "DuCoin: minter does not exist");
        minters[minter] = false;
        emit MinterRemoved(minter);
    }
}
