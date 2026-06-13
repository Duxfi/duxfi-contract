// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DuxRouter} from "../src/periphery/DuxRouter.sol";

/**
 * @title DeployRouter
 * @notice Deploy DuxRouter contract separately
 */
contract DeployRouter is Script {
    using stdJson for string;

    DuxRouter public router;

    function run() public {
        address deployerAddress = msg.sender;
        console2.log("=== Deploying DuxRouter ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployerAddress);

        // Read factory address from config
        address factoryAddress = getFactoryAddress();
        console2.log("DuxFactory address:", factoryAddress);

        vm.startBroadcast();
        
        router = new DuxRouter(factoryAddress);

        vm.stopBroadcast();

        console2.log("DuxRouter deployed at:", address(router));
        
        // Update chain config
        _updateChainConfig(address(router));
    }

    function getFactoryAddress() internal view returns (address) {
        string memory path = string.concat("frontend/chain_", vm.toString(block.chainid), ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".DuxFactory");
    }

    function _updateChainConfig(address routerAddress) internal {
        string memory configPath = string.concat("frontend/chain_", vm.toString(block.chainid), ".json");
        string memory json = vm.readFile(configPath);
        address factoryAddress = json.readAddress(".DuxFactory");

        // Build new JSON, preserve existing fields
        string memory newJson = "{\n";
        newJson = string.concat(newJson, '  "chainId": ', vm.toString(block.chainid), ",\n");
        newJson = string.concat(newJson, '  "DuxFactory": "', vm.toString(factoryAddress), "\",\n");
        newJson = string.concat(newJson, '  "DuxRouter": "', vm.toString(routerAddress), "\"\n");

        // Preserve DuxFaucet field
        address faucet = _safeReadAddress(json, ".DuxFaucet");
        if (faucet != address(0)) {
            newJson = string.concat(newJson, '  "DuxFaucet": "', vm.toString(faucet), "\"\n");
        }

        newJson = string.concat(newJson, "}");

        vm.writeFile(configPath, newJson);
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
