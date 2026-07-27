// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DuCoin} from "../src/core/DuCoin.sol";
import {DuxFaucet} from "../src/periphery/DuxFaucet.sol";

contract ConfigureFauceToken is Script {
    using stdJson for string;

    /**
     * @notice Configure DuxFaucet with a single token and daily amount
     * @param tokenAddr The address of the token
     * @param dailyAmount The daily amount to claim for the token
     */
    function run(address tokenAddr, uint256 dailyAmount) public {
        // Check parameters
        if (tokenAddr == address(0)) {
            console2.log("Error: Token address cannot be zero");
            console2.log(
                "Usage: forge script ... --sig \"run(address,uint256)\" 0xTokenAddress 10000000000000000000000"
            );
            revert("Token address is zero");
        }

        if (dailyAmount == 0) {
            console2.log("Error: Daily amount cannot be zero");
            console2.log(
                "Usage: forge script ... --sig \"run(address,uint256)\" 0xTokenAddress 10000000000000000000000"
            );
            revert("Daily amount is zero");
        }

        address deployerAddress = msg.sender;
        console2.log("=== Configuring DuxFaucet ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployerAddress);

        // Prepare token array
        address[] memory tokenAddrs = new address[](1);
        tokenAddrs[0] = tokenAddr;
        uint256[] memory dailyAmounts = new uint256[](1);
        dailyAmounts[0] = dailyAmount;

        // Get faucet address from config
        address payable faucetAddress = getDuxFaucetAddress();
        console2.log("DuxFaucet address:", faucetAddress);

        console2.log("Token address:", tokenAddrs[0]);
        console2.log("Token daily amount:", dailyAmounts[0]);

        vm.startBroadcast();
        DuCoin(tokenAddr).addMinter(faucetAddress);
        DuxFaucet(faucetAddress).setTokens(tokenAddrs, dailyAmounts);
        vm.stopBroadcast();

        console2.log("DuxFaucet configured successfully");
    }

    function getDuxFaucetAddress() internal view returns (address payable) {
        string memory path = string.concat("frontend/chain_", vm.toString(block.chainid), ".json");
        // forge-lint: disable-next-line(unsafe-cheatcode)
        string memory json = vm.readFile(path);
        return payable(json.readAddress(".DuxFaucet"));
    }
}
