// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {DuCoin} from "../src/core/DuCoin.sol";

contract DeployTokens is Script {
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
    }

    DuCoin[] private deployedTokens;

    function faucetTokens() private pure returns (TokenConfig[] memory) {
        TokenConfig[] memory configs = new TokenConfig[](9);
        configs[0] = TokenConfig({name: "Dux Coin", symbol: "DUX", decimals: 18});
        configs[1] = TokenConfig({name: "Bitcoin", symbol: "BTC", decimals: 8});
        configs[2] = TokenConfig({name: "Tether USD", symbol: "USDT", decimals: 6});
        configs[3] = TokenConfig({name: "Ethereum", symbol: "ETH", decimals: 18});
        configs[4] = TokenConfig({name: "Solana", symbol: "SOL", decimals: 18});
        configs[5] = TokenConfig({name: "USDC", symbol: "USDC", decimals: 6});
        configs[6] = TokenConfig({name: "DAI", symbol: "DAI", decimals: 18});
        configs[7] = TokenConfig({name: "LINK", symbol: "LINK", decimals: 18});
        configs[8] = TokenConfig({name: "OKX Coin", symbol: "OKB", decimals: 18});
        return configs;
    }

    function run() public {
        vm.startBroadcast();
        
        address deployerAddress = msg.sender;
        console2.log("=== Deploying Tokens ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployerAddress);

        TokenConfig[] memory faucetTokensConfigs = faucetTokens();
        for (uint256 i = 0; i < faucetTokensConfigs.length; i++) {
            TokenConfig memory tokenConfig = faucetTokensConfigs[i];
            DuCoin mockToken = new DuCoin(tokenConfig.name, tokenConfig.symbol, tokenConfig.decimals);
            deployedTokens.push(mockToken);
            console2.log(string.concat(tokenConfig.name, " deployed at:"), address(mockToken));
        }

        vm.stopBroadcast();

        string memory json = "{\n";
        json = string.concat(json, "  \"name\": \"Dux TokenList\",\n");
        json = string.concat(json, "  \"chainId\": ", vm.toString(block.chainid), ",\n");
        json = string.concat(json, "  \"tokenCount\": ", vm.toString(deployedTokens.length), ",\n");
        json = string.concat(json, "  \"faucetTokens\": [\n");
        for (uint256 i = 0; i < deployedTokens.length; i++) {
            TokenConfig memory tokenConfig = faucetTokensConfigs[i];
            json = string.concat(json, "    {\n");
            json = string.concat(json, "      \"chainId\": ", vm.toString(block.chainid), ",\n");
            json = string.concat(json, "      \"address\": \"", vm.toString(address(deployedTokens[i])), "\",\n");
            json = string.concat(json, "      \"name\": \"", tokenConfig.name, "\",\n");
            json = string.concat(json, "      \"symbol\": \"", tokenConfig.symbol, "\",\n");
            json = string.concat(json, "      \"decimals\": ", vm.toString(tokenConfig.decimals), "\n");
            json = string.concat(json, i == deployedTokens.length - 1 ? "    }\n" : "    },\n");
        }
        
        json = string.concat(json, "  ]\n");
        json = string.concat(json, "}");

        string memory tokenListPath = string.concat("frontend/dux_tokens_", vm.toString(block.chainid), ".json");
        vm.writeFile(tokenListPath, json);
        console2.log("Token config file generated at:", tokenListPath);
    }
}