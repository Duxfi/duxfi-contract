// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseFixture} from "./BaseFixture.sol";
import {DuxRouter} from "../../../src/periphery/DuxRouter.sol";
import {DuCoin} from "../../../src/core/DuCoin.sol";



contract RouterFixture is BaseFixture {
    DuxRouter router;
    DuCoin private _duCoin;

    // create facotry and new pool in super, create a mock empty pool for DUX and WETH

    function setUp() public virtual override {
        super.setUp();
        router = new DuxRouter(factory);
    }

    function mintPoolAll() internal {
        mintPoolUsdcWeth();
        mintPoolWethDuxc();
        mintPoolDuxcBtc();
        mintPoolBtcDai();
        mintPoolDaiMockToken();
    }

    function mintDuCoinToUser(uint256 amount, address user) public {
        _duCoin.mint(user, amount);
    }

    function getUsdcWethPaths() public view returns (address[] memory) {
        address[] memory paths = new address[](2);
        paths[0] = usdc;
        paths[1] = weth;
        return paths;
    }

    function getUsdcWethDuxPaths() public view returns (address[] memory paths) {
        paths = new address[](3);
        paths[0] = usdc;
        paths[1] = weth;
        paths[2] = duxc;
        return paths;
    }

    function getPairsUsdcWethDuxPaths() public view returns (address[] memory pairs) {
        pairs = new address[](2);
        pairs[0] = duxFactory.getPairByTokens(usdc, weth);
        pairs[1] = duxFactory.getPairByTokens(weth, duxc);
    }

    function getPathsFromUsdcToDai() public view returns (address[] memory paths) {
        paths = new address[](5);
        address[] memory reusePaths = getUsdcWethDuxPaths();
        for (uint256 i = 0; i < reusePaths.length; i++) {
            paths[i] = reusePaths[i];
        }
        paths[3] = btc;
        paths[4] = dai;
    }

    function getPairsFromUsdcToDai() public view returns (address[] memory orderedPairs) {
        orderedPairs = new address[](4);
        orderedPairs[0] = duxFactory.getPairByTokens(usdc, weth);
        orderedPairs[1] = duxFactory.getPairByTokens(weth, duxc);
        orderedPairs[2] = duxFactory.getPairByTokens(duxc, btc);
        orderedPairs[3] = duxFactory.getPairByTokens(btc, dai);
    }

    function getMaxPaths() public view returns (address[] memory paths) {
        paths = new address[](6);
        address[] memory reusePaths = getPathsFromUsdcToDai();
        for (uint256 i = 0; i < reusePaths.length; i++) {
            paths[i] = reusePaths[i];
        }
        paths[5] = mockToken;
    }
}
