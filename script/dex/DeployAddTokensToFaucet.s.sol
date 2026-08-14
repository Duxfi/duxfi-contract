// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DuCoin} from "@dex/core/DuCoin.sol";
import {DuxFaucet} from "@dex/periphery/DuxFaucet.sol";


contract DeployAddTokensToFaucet is Script {
    using stdJson for string;

    /**
     * @notice Add the token to DuxFaucet contract to allow users to claim the token
     * @param faucetAddress The address of the DuxFaucet contract
     * @param tokenAddr The address of the token
     * @param tokenDecimal The decimals of the token (e.g. 6 for USDC, 18 for DUX)
     * @param amountUnit The human-readable amount per claim (e.g. 10000 for 10000 USDC)
     */
    function run(address faucetAddress, address tokenAddr, uint256 tokenDecimal, uint256 amountUnit) public {
        if (faucetAddress == address(0)) {
            console2.log("Error: Faucet address cannot be zero");
            console2.log(
                "Usage: forge script ... --sig \"run(address,address,uint256,uint256)\" 0xFaucetAddress 0xTokenAddress 6 10000"
            );
            revert("Faucet address is zero");
        }
        if (tokenAddr == address(0)) {
            console2.log("Error: Token address cannot be zero");
            console2.log(
                "Usage: forge script ... --sig \"run(address,address,uint256,uint256)\" 0xFaucetAddress 0xTokenAddress 6 10000"
            );
            revert("Token address is zero");
        }

        if (tokenDecimal > 18) {
            console2.log("Error: Token decimal cannot exceed 18");
            console2.log(
                "Usage: forge script ... --sig \"run(address,address,uint256,uint256)\" 0xFaucetAddress 0xTokenAddress 6 10000"
            );
            revert("Token decimal too large");
        }

        if (amountUnit == 0) {
            console2.log("Error: Amount unit cannot be zero");
            console2.log(
                "Usage: forge script ... --sig \"run(address,address,uint256,uint256)\" 0xFaucetAddress 0xTokenAddress 6 10000"
            );
            revert("Amount unit is zero");
        }

        uint256 dailyAmount = amountUnit * (10 ** tokenDecimal);

        address deployerAddress = msg.sender;
        console2.log("=== Configuring DuxFaucet ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployerAddress);
        console2.log("Faucet address:", faucetAddress);
        console2.log("Token address:", tokenAddr);
        console2.log("Token decimal:", tokenDecimal);
        console2.log("Amount unit:", amountUnit);
        console2.log("Daily amount (raw):", dailyAmount);

        vm.startBroadcast();
        DuCoin(tokenAddr).addMinter(faucetAddress);
        DuxFaucet(payable(faucetAddress)).addToken(tokenAddr, dailyAmount);
        vm.stopBroadcast();

        console2.log("DuxFaucet configured successfully");
    }

}
