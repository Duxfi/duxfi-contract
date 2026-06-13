// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DuxFactory} from "../../../src/core/DuxFactory.sol";
import {DuxPair} from "../../../src/core/DuxPair.sol";
import {DuCoin} from "../../../src/core/duCoin.sol";
import {MockERC} from "../../mocks/MockERC.sol";

contract BaseFixture is Test {
    DuxFactory duxFactory;
    address public factory;
    address public usdc;
    address public weth;
    address duxc;
    address btc;
    address dai;
    address mockToken;

    address public pairUsdcWeth;
    address public pairDuxWeth;
    address public pairDuxcBtc;
    address public pairBtcDai;
    address public pairDaiMockToken;

    DuCoin private _duCoin;

    uint16 public constant SWAP_FEE_BPS = 30;
    uint256 public minLiquidity;
    uint256 public feeDenominator;

    // User addresses
    address public constant USER1 = address(0x1000000000000000000000000000000000000000);
    address public constant USER2 = address(0x2000000000000000000000000000000000000000);
    address public constant USER3 = address(0x3000000000000000000000000000000000000000);
    address public constant USER4 = address(0x4000000000000000000000000000000000000000);
    // Token decimals
    uint256 public constant DECIMAL_6 = 10 ** 6;
    uint256 public constant DECIMAL_18 = 10 ** 18;

    // Common amounts
    uint256 public constant AMOUNT_INIT_USDC = 200000 * DECIMAL_6;
    uint256 public constant AMOUNT_INIT_WETH = 100 ether;

    uint256 constant MINTED_INIT_DUX = 300000 * DECIMAL_18;
    uint256 constant MINTED_INIT_BTC = 500000 * 10 ** 8;
    uint256 constant MINTED_INIT_DAI = 600000 * DECIMAL_18;
    uint256 constant MINTED_INIT_MOCK_TOKEN = 700000 * DECIMAL_18;

    uint256 public constant AMOUNT_ADDLIQ_USDC = 40000 * DECIMAL_6;
    uint256 public constant AMOUNT_ADDLIQ_WETH = 20 ether;
    uint256 public constant AMOUNT_TOO_SMALL_USDC = 20;
    uint256 public constant AMOUNT_TOO_SMALL_WETH = 10;

    // create a new factory and create a mock empty pool for USDC and WETH
    function setUp() public virtual {
        // Deploy tokens
        usdc = address(new MockERC("USDC", "USDC", 6));
        weth = address(new MockERC("WETH", "WETH", 18));
        btc = address(new MockERC("BTC", "BTC", 8));
        dai = address(new MockERC("DAI", "DAI", 18));
        mockToken = address(new MockERC("MockToken", "MockToken", 18));

        // create dux coin
        _duCoin = new DuCoin("DuCoin", "DUC", 18);
        duxc = address(_duCoin);

        // Deploy factory and create pair
        duxFactory = new DuxFactory();
        factory = address(duxFactory);

        // create pair WETH-DUX
        pairUsdcWeth = duxFactory.createPair(usdc, weth, SWAP_FEE_BPS, address(this));
        pairDuxWeth = duxFactory.createPair(duxc, weth, SWAP_FEE_BPS, address(this));
        pairDuxcBtc = duxFactory.createPair(btc, duxc, SWAP_FEE_BPS, address(this));
        pairBtcDai = duxFactory.createPair(btc, dai, SWAP_FEE_BPS, address(this));
        pairDaiMockToken = duxFactory.createPair(dai, mockToken, SWAP_FEE_BPS, address(this));

        minLiquidity = DuxPair(pairUsdcWeth).MINIMUM_LIQUIDITY();
        feeDenominator = DuxPair(pairUsdcWeth).FEE_DENOMINATOR();

        // console.log("=======BaseFixture Setup=======");
        // console.log("Factory:", address(factory));
        // console.log("USDC:", usdc);
        // console.log("WETH:", weth);
        // console.log("pairUsdcWeth:", address(pairUsdcWeth));
        // console.log("pairDuxWeth:", address(pairDuxWeth));
        // console.log("pairDuxcBtc:", address(pairDuxcBtc));
        // console.log("pairBtcDai:", address(pairBtcDai));
        // console.log("pairDaiMockToken:", address(pairDaiMockToken));
    }

    //@dev should not be used for DuPair mintLpToken related tests
    function mintPoolUsdcWeth() internal {
        _mintPoolInt(USER1, pairUsdcWeth, usdc, weth, AMOUNT_INIT_USDC, AMOUNT_INIT_WETH);
    }
    //@dev should not be used for DuPair mintLpToken related tests

    function mintPoolWethDuxc() internal {
        _mintPoolInt(USER1, pairDuxWeth, duxc, weth, MINTED_INIT_DUX, AMOUNT_INIT_WETH);
    }
    //@dev should not be used for DuPair mintLpToken related tests

    function mintPoolDuxcBtc() internal {
        _mintPoolInt(USER1, pairDuxcBtc, btc, duxc, MINTED_INIT_BTC, MINTED_INIT_DUX);
    }
    //@dev should not be used for DuPair mintLpToken related tests

    function mintPoolBtcDai() internal {
        _mintPoolInt(USER1, pairBtcDai, btc, dai, MINTED_INIT_BTC, MINTED_INIT_DAI);
    }
    //@dev should not be used for DuPair mintLpToken related tests

    function mintPoolDaiMockToken() internal {
        _mintPoolInt(USER1, pairDaiMockToken, dai, mockToken, MINTED_INIT_DAI, MINTED_INIT_MOCK_TOKEN);
    }

    //@dev should not be used for DuPair mintLpToken related tests
    function _mintPoolInt(address user, address pair, address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        private
    {
        mintToAndTransferToContract(user, pair, tokenA, tokenB, amountA, amountB);
        DuxPair(pair).mintLpToken(user);
    }

    function mintToAndTransferToContract(
        address user,
        address _contract,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        _mintToUser(user, tokenA, amountA, tokenB, amountB);
        _approveToContract(user, _contract, tokenA, tokenB, amountA, amountB);
        transferToContract(user, _contract, tokenA, tokenB, amountA, amountB);
    }
    //@dev minted by own prank, must put this function out of outsider prank

    function mintAndApproveToContract(
        address user,
        address _contract,
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB
    ) internal {
        _mintToUser(user, _tokenA, _amountA, _tokenB, _amountB);
        _approveToContract(user, _contract, _tokenA, _tokenB, _amountA, _amountB);
    }

    function _mintToUser(address user, address tokenA, uint256 amountA, address tokenB, uint256 amountB) private {
        address owner = MockERC(tokenA).owner();
        vm.startPrank(owner);
        MockERC(tokenA).mint(user, amountA);
        MockERC(tokenB).mint(user, amountB);
        vm.stopPrank();
    }

    function _approveToContract(
        address user,
        address _contract,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) private {
        vm.startPrank(user);
        MockERC(tokenA).approve(_contract, amountA);
        MockERC(tokenB).approve(_contract, amountB);
        vm.stopPrank();
    }

    function transferToContract(
        address user,
        address _contract,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        vm.startPrank(user);
        bool success1 = MockERC(tokenA).transfer(_contract, amountA);
        bool success2 = MockERC(tokenB).transfer(_contract, amountB);
        require(success1 && success2, "Transfer failed");
        vm.stopPrank();
    }
}
