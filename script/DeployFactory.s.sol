// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DuxFactory} from "../src/core/DuxFactory.sol";

/**
 * @title DeployFactory
 * @notice Deploy DuxFactory contract separately
 */
contract DeployFactory is Script {
    using stdJson for string;

    DuxFactory public factory;

    function run() public {
        address deployerAddress = msg.sender;
        console2.log("=== Deploying DuxFactory ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployerAddress);

        vm.startBroadcast();
        
        factory = new DuxFactory();

        vm.stopBroadcast();

        console2.log("DuxFactory deployed at:", address(factory));
        
        // Update chain config
        _updateChainConfig(address(factory));
    }

    function _updateChainConfig(address factoryAddress) internal {
        string memory configPath = string.concat("frontend/chain_", vm.toString(block.chainid), ".json");

        if (vm.exists(configPath)) {    
            // forge-lint: disable-next-line(unsafe-cheatcode)
            string memory json = vm.readFile(configPath);
            string memory newJson = "{\n";
            newJson = string.concat(newJson, '  "chainId": ', vm.toString(block.chainid), ",\n");
            newJson = string.concat(newJson, '  "DuxFactory": "', vm.toString(factoryAddress), "\"\n");

            // Preserve other existing fields
            address router = _safeReadAddress(json, ".DuxRouter");
            if (router != address(0)) {
                newJson = string.concat(newJson, '  "DuxRouter": "', vm.toString(router), "\",\n");
            }

            address faucet = _safeReadAddress(json, ".DuxFaucet");
            if (faucet != address(0)) {
                newJson = string.concat(newJson, '  "DuxFaucet": "', vm.toString(faucet), "\"\n");
            }

            newJson = string.concat(newJson, "}");
            // forge-lint: disable-next-line(unsafe-cheatcode)
            vm.writeFile(configPath, newJson);
        } else {
            string memory newJson = string.concat(
                "{\n",
                '  "chainId": ', vm.toString(block.chainid), ",\n",
                '  "DuxFactory": "', vm.toString(factoryAddress), "\"\n",
                "}"
            );
            // forge-lint: disable-next-line(unsafe-cheatcode)
            vm.writeFile(configPath, newJson);
        }

        console2.log("Chain config updated at:", configPath);
    }

    function _safeReadAddress(string memory json, string memory key) internal pure returns (address) {
        // Safe read address with try/catch, return address(0) if not found
        try vm.parseJson(json, key) returns (bytes memory data) {
            if (data.length == 0) return address(0);
            return abi.decode(data, (address));
        } catch {
            return address(0);
        }
    }
}
