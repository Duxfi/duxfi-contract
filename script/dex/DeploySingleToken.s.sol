// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {DuCoin} from "@dex/core/DuCoin.sol";

/**
 * @title DeploySingleToken
 * @notice Script to deploy a single token using Du DuCoin contract
 */
contract DeploySingleToken is Script {
    function run(string memory name, string memory symbol, uint8 decimals) public {
        console2.log("=== Deploying Token ===");
        console2.log("Name:", name);
        console2.log("Symbol:", symbol);
        console2.log("Decimals:", decimals);

        vm.startBroadcast();
        
        DuCoin token = new DuCoin(name, symbol, decimals);
        console2.log("Token deployed at:", address(token));
        
        vm.stopBroadcast();

        // Save token address to file (append mode)
        string memory filePath = "./frontend/token-addresses.txt";
        string memory entry = string.concat(
            "chainId:",
            vm.toString(block.chainid),
            " name:",
            name,
            " symbol:",
            symbol,
            " address:",
            vm.toString(address(token)),
            "\n"
        );
        // forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeLine(filePath, entry);
        console2.log("Token info appended to:", filePath);
    }
}