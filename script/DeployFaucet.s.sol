// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DuxFaucet} from "../src/periphery/DuxFaucet.sol";

/**
 * @title DeployFaucet
 * @notice Deploy DuxFaucet contract separately
 */
contract DeployFaucet is Script {
    using stdJson for string;

    DuxFaucet public faucet;

    function run() public {
        address deployerAddress = msg.sender;
        console2.log("=== Deploying DuxFaucet ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployerAddress);

        vm.startBroadcast();

        faucet = new DuxFaucet();

        vm.stopBroadcast();

        console2.log("DuxFaucet deployed at:", address(faucet));

        // Update chain config
        _updateChainConfig(address(faucet));
    }

    function _updateChainConfig(address faucetAddress) internal {
        string memory configPath = string.concat("frontend/chain_", vm.toString(block.chainid), ".json");

        if (vm.exists(configPath)) {
                // forge-lint: disable-next-line(unsafe-cheatcode)
            string memory json = vm.readFile(configPath);
            // Build new JSON, preserve existing fields
            string memory newJson = "{\n";
            newJson = string.concat(newJson, '  "chainId": ', vm.toString(block.chainid), ",\n");

            // Read existing fields
            address factory = _safeReadAddress(json, ".DuxFactory");
            if (factory != address(0)) {
                newJson = string.concat(newJson, '  "DuxFactory": "', vm.toString(factory), "\",\n");
            }

            address router = _safeReadAddress(json, ".DuxRouter");
            if (router != address(0)) {
                newJson = string.concat(newJson, '  "DuxRouter": "', vm.toString(router), "\",\n");
            }

            newJson = string.concat(newJson, '  "DuxFaucet": "', vm.toString(faucetAddress), "\"\n");
            newJson = string.concat(newJson, "}");
            // forge-lint: disable-next-line(unsafe-cheatcode)
            vm.writeFile(configPath, newJson);
        } else {
            string memory newJson = string.concat(
                "{\n",
                '  "chainId": ',
                vm.toString(block.chainid),
                ",\n",
                '  "DuxFaucet": "',
                vm.toString(faucetAddress),
                "\"\n",
                "}"
            );
            // forge-lint: disable-next-line(unsafe-cheatcode)
            vm.writeFile(configPath, newJson);
        }

        console2.log("Chain config updated at:", configPath);
    }

    function _safeReadAddress(string memory json, string memory key) internal pure returns (address) {
        try vm.parseJson(json, key) returns (bytes memory data) {
            if (data.length == 0) return address(0);
            return abi.decode(data, (address));
        } catch {
            return address(0);
        }
    }
}
