// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {DuxFactory} from "../src/core/DuxFactory.sol";
import {DuxRouter} from "../src/periphery/DuxRouter.sol";
import {DuxFaucet} from "../src/periphery/DuxFaucet.sol";

contract DeployCores is Script {
    DuxFactory public factory;
    DuxRouter public router;
    DuxFaucet public duxFaucet;

    function run() public {
        address deployerAddress = msg.sender;
        console2.log("=== Deploying Core Contracts ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployerAddress);

        vm.startBroadcast();
        
        factory = new DuxFactory();
        router = new DuxRouter(address(factory));
        duxFaucet = new DuxFaucet();

        vm.stopBroadcast();

        console2.log("DuxFactory deployed at:", address(factory));
        console2.log("DuxRouter deployed at:", address(router));
        console2.log("DuxFaucet deployed at:", address(duxFaucet));
        
        // Export config: { "chainId": xxx, "DuxFactory": "0x...", "DuxRouter": "0x...", "DuxFaucet": "0x..." }
        string memory json = "{\n";
        json = string.concat(json, "  \"chainId\": ", vm.toString(block.chainid), ",\n");
        json = string.concat(json, "  \"DuxFactory\": \"", vm.toString(address(factory)), "\",\n");
        json = string.concat(json, "  \"DuxRouter\": \"", vm.toString(address(router)), "\",\n");
        json = string.concat(json, "  \"DuxFaucet\": \"", vm.toString(address(duxFaucet)), "\"\n");
        json = string.concat(json, "}");

        string memory configPath = string.concat("frontend/chain_", vm.toString(block.chainid), ".json");
        // forge-lint: disable-next-line(unsafe-cheatcode)
        vm.writeFile(configPath, json);
        console2.log("Chain config file generated at:", configPath);
    }

    
}