// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "../src/ERC20/ERC20.sol";
import {Comptroller} from "../src/Comptroller.sol";
import {Unitroller} from "../src/Unitroller.sol";
import {CErc20Delegate} from "../src/CErc20Delegate.sol";
import {CErc20Delegator} from "../src/CErc20Delegator.sol";
import {WhitePaperInterestRateModel} from "../src/WhitePaperInterestRateModel.sol";
import {SimplePriceOracle} from "../src/SimplePriceOracle.sol";
import {CToken} from "../src/CToken.sol";
import {ETFErc20} from "../src/ETFErc20.sol";
import {ETFErc20InterFace} from "../src/ETFErc20InterFace.sol";


contract ETFTest is Test {
    ERC20 public wBTC;
    ERC20 public wETH;
    CErc20Delegator public cWBTC;
    CErc20Delegator public cWETH;
    CErc20Delegate public cErc20Delegate;
    Comptroller public comptroller;
    Unitroller public unitroller;
    Comptroller public unitrollerProxy;
    WhitePaperInterestRateModel public whitePaperInterestRateModel;
    SimplePriceOracle public simplePriceOracle;
    SimplePriceOracle public priceOracle;
    ETFErc20 public wbtc_weth_eft;

    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");

    function setUp() public {
        vm.startPrank(admin);
        wBTC = new erc20Token("wBTC","wBTC");
        wETH = new erc20Token("wETH","wETH");

        //InterestRateModel
        whitePaperInterestRateModel=new WhitePaperInterestRateModel(0,0);

        //PriceOracle
        priceOracle = new SimplePriceOracle();

        //Comptroller
        comptroller = new Comptroller();
        unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        unitrollerProxy = Comptroller(address(unitroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);

        cErc20Delegate = new CErc20Delegate();

        cWBTC = new CErc20Delegator(
            address(wBTC),
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e18,
            "cWBTC",
            "cWBTC",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        unitrollerProxy._supportMarket(CToken(address(cWBTC)));

        cWETH = new CErc20Delegator(
            address(wETH),
            unitrollerProxy,
            whitePaperInterestRateModel,
            1e18,
            "cWETH",
            "cWETH",
            18,
            payable(admin),
            address(cErc20Delegate),
            new bytes(0)
        );
        unitrollerProxy._supportMarket(CToken(address(cWETH)));

        //ETF Token
        //1顆EFT = 0.01 wBTC + 0.2 wETH
        ETFErc20InterFace.ETF[] memory ETFList = new ETFErc20InterFace.ETF[](2);

        //假設wBTC 40000U，0.01顆(0.01*1e18)為新的1顆eft token比例，最少要0.001顆wBTC
        ETFErc20InterFace.ETF memory WBTCElement = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(cWBTC),
                proportion: 0.01 * 1e18,
                minimum: 0.001 * 1e18
            });
        ETFList[0] = WBTCElement;

        //假設wETH 2000U，0.2顆(0.2*1e18)為新的1顆eft token比例，最少要0.02顆wETH
        ETFErc20InterFace.ETF memory WETHElement = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(cWETH),
                proportion: 0.2 * 1e18,
                minimum: 0.02 * 1e18
            });
        ETFList[1] = WETHElement;

        wbtc_weth_eft = new ETFErc20("wbtc_weth_eft", "wbtc_weth_eft",  "wbtc_weth_eft", ETFList);
        wbtc_weth_eft._setComptroller(unitrollerProxy);
        //可以supportEFTMarket條件對應的cToken地址都需要supportMarket
        uint code = unitrollerProxy._supportEFTMarket(address(wbtc_weth_eft));
        assertEq(code, 0);
    }

    //剛好數字比例的mint與redeem
    function test_mint_redeem() public {
        vm.startPrank(user1);
        deal(address(wBTC), user1, 0.01 ether);
        deal(address(wETH), user1, 0.2 ether);
        ETFErc20InterFace.ETF[] memory etfMint = new ETFErc20InterFace.ETF[](2);

        ETFErc20InterFace.ETF memory WBTCElement = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(0),
                proportion: 0.01 * 1e18,
                minimum: 0
            });
        etfMint[0] = WBTCElement;

        ETFErc20InterFace.ETF memory WETHElement = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(0),
                proportion: 0.2 * 1e18,
                minimum: 0
            });
        etfMint[1] = WETHElement;
        wBTC.approve(address(wbtc_weth_eft),  0.01 * 1e18);
        wETH.approve(address(wbtc_weth_eft), 0.2 * 1e18);
        wbtc_weth_eft.mint(etfMint);
        assertEq(wbtc_weth_eft.balanceOf(user1), 1 * 1e18);
        assertEq(wBTC.balanceOf(user1), 0);
        assertEq(wETH.balanceOf(user1), 0);
        assertEq(cWBTC.balanceOf(address(wbtc_weth_eft)), 0.01 * 1e18);
        assertEq(cWETH.balanceOf(address(wbtc_weth_eft)), 0.2 * 1e18);

        wbtc_weth_eft.redeem(wbtc_weth_eft.balanceOf(user1));
        assertEq(wbtc_weth_eft.balanceOf(user1), 0);
        assertEq(wBTC.balanceOf(user1), 0.01 * 1e18);
        assertEq(wETH.balanceOf(user1), 0.2 * 1e18);
        assertEq(cWBTC.balanceOf(address(wbtc_weth_eft)), 0);
        assertEq(cWETH.balanceOf(address(wbtc_weth_eft)), 0);
        
    }


    //不正確比例的mint
    function test_mint_payback() public {
        vm.startPrank(user1);
        deal(address(wBTC), user1, 0.01 ether);
        deal(address(wETH), user1, 0.3 ether);
        ETFErc20InterFace.ETF[] memory etfMint = new ETFErc20InterFace.ETF[](2);

        ETFErc20InterFace.ETF memory WBTCElement = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(0),
                proportion: 0.01 * 1e18,
                minimum: 0
            });
        etfMint[0] = WBTCElement;

        ETFErc20InterFace.ETF memory WETHElement = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(0),
                proportion: 0.3 * 1e18,
                minimum: 0
            });
        etfMint[1] = WETHElement;
        wBTC.approve(address(wbtc_weth_eft),  0.01 * 1e18);
        wETH.approve(address(wbtc_weth_eft), 0.2 * 1e18);
        wbtc_weth_eft.mint(etfMint);
        assertEq(wbtc_weth_eft.balanceOf(user1), 1 * 1e18);
        assertEq(wBTC.balanceOf(user1), 0);
        //因為依比例只需要0.2 eth，而參數去傳入0.3 eth，但是合約實際只會接收0.2 eth
        assertEq(wETH.balanceOf(user1), 0.1 * 1e18);
        assertEq(cWBTC.balanceOf(address(wbtc_weth_eft)), 0.01 * 1e18);
        assertEq(cWETH.balanceOf(address(wbtc_weth_eft)), 0.2 * 1e18);
        
    }
}

contract erc20Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}
