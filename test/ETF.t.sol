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
import {ETFErc20v2} from "../src/UUPS/ETFErc20v2.sol";
import {ETFErc20Delegator} from "../src/ETFErc20Delegator.sol";
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
    address public ethHolder1 = makeAddr("ethHolder1");
    address public ethHolder2 = makeAddr("ethHolder2");
    address public ethHolder3 = makeAddr("ethHolder3");
    address public compoundBorrower1 = makeAddr("compoundBorrower1");
    address public compoundBorrower2 = makeAddr("compoundBorrower2");

    function setUp() public {
        vm.startPrank(admin);
        wBTC = new erc20Token("wBTC","wBTC");
        wETH = new erc20Token("wETH","wETH");

        //InterestRateModel
        whitePaperInterestRateModel=new WhitePaperInterestRateModel(10 * 10**18  ,10 * 10**18);

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
        //在 Oracle 中設定一顆 WBTC 的價格為 $40000，一顆 WETH 的價格為 $2000
        priceOracle.setUnderlyingPrice(CToken(address(cWBTC)),40000 * 1e18);
        priceOracle.setUnderlyingPrice(CToken(address(cWETH)),2000 * 1e18);

        //cWBTC,cWETH 的 collateral factor 為 90%
        unitrollerProxy._setCollateralFactor(CToken(address(cWBTC)),0.9 * 1e18);
        unitrollerProxy._setCollateralFactor(CToken(address(cWETH)),0.9 * 1e18);

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
        

       ETFErc20 eft = new ETFErc20();

       //initialize 参数 : name, symbol, decimals, description, token List, mantissa, interestBlockPrior  
       ETFErc20Delegator ETF_Proxy = new ETFErc20Delegator(
            abi.encodeWithSelector(eft.initialize.selector, "wbtc_weth_eft", "BET", 18
            , "wbtc_weth_eft", ETFList, 1e18, 2102400),
            address(eft)
        );

        //ETF UUPS Proxy
        wbtc_weth_eft = ETFErc20(address(ETF_Proxy));
        wbtc_weth_eft._setComptroller(unitrollerProxy);
        //可以supportEFTMarket條件對應的cToken地址都需要supportMarket
        uint code = unitrollerProxy._supportEFTMarket(address(wbtc_weth_eft));
        assertEq(code, 0);
    }

    //剛好數字比例的mint與redeem
    function test_mint_redeem() public {
        vm.startPrank(ethHolder1);
        deal(address(wBTC), ethHolder1, 0.01 ether);
        deal(address(wETH), ethHolder1, 0.2 ether);
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
        assertEq(wbtc_weth_eft.balanceOf(ethHolder1), 1 * 1e18);
        assertEq(wBTC.balanceOf(ethHolder1), 0);
        assertEq(wETH.balanceOf(ethHolder1), 0);
        assertEq(cWBTC.balanceOf(address(wbtc_weth_eft)), 0.01 * 1e18);
        assertEq(cWETH.balanceOf(address(wbtc_weth_eft)), 0.2 * 1e18);

        wbtc_weth_eft.redeem(wbtc_weth_eft.balanceOf(ethHolder1));
        assertEq(wbtc_weth_eft.balanceOf(ethHolder1), 0);
        assertEq(wBTC.balanceOf(ethHolder1), 0.01 * 1e18);
        assertEq(wETH.balanceOf(ethHolder1), 0.2 * 1e18);
        assertEq(cWBTC.balanceOf(address(wbtc_weth_eft)), 0);
        assertEq(cWETH.balanceOf(address(wbtc_weth_eft)), 0);
        
    }

    //不正確比例的mint
    function test_mint_payback() public {
        vm.startPrank(ethHolder1);
        deal(address(wBTC), ethHolder1, 0.01 ether);
        deal(address(wETH), ethHolder1, 0.3 ether);
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
        assertEq(wbtc_weth_eft.balanceOf(ethHolder1), 1 * 1e18);
        assertEq(wBTC.balanceOf(ethHolder1), 0);
        //因為依比例只需要0.2 eth，而參數去傳入0.3 eth，但是合約實際只會接收0.2 eth
        assertEq(wETH.balanceOf(ethHolder1), 0.1 * 1e18);
        assertEq(cWBTC.balanceOf(address(wbtc_weth_eft)), 0.01 * 1e18);
        assertEq(cWETH.balanceOf(address(wbtc_weth_eft)), 0.2 * 1e18);
        
    }

    //單一user簡單claim利息
    function test_borrow_claim1() public {
        _EtfOneUserMint();
        vm.startPrank(compoundBorrower1);
        deal(address(wBTC), compoundBorrower1, 1000 ether);
        deal(address(wETH), compoundBorrower1, 10000 ether);
        wBTC.approve(address(cWBTC), type(uint256).max);
        wETH.approve(address(cWETH), type(uint256).max);
        cWBTC.mint(1000 ether);

        address[] memory cTokenAddr = new address[](1);
        cTokenAddr[0] = address(cWBTC);
        unitrollerProxy.enterMarkets(cTokenAddr);
        cWETH.borrow(100 ether);
        vm.roll(10000000);
        cWETH.repayBorrow(cWETH.borrowBalanceCurrent(compoundBorrower1));

        deal(address(wBTC), compoundBorrower2, 5000 ether);
        deal(address(wETH), compoundBorrower2, 100000 ether);
        vm.startPrank(compoundBorrower2);
        wBTC.approve(address(cWBTC), type(uint256).max);
        wETH.approve(address(cWETH), type(uint256).max);
        cWETH.mint(wETH.balanceOf(compoundBorrower2));
        cTokenAddr[0] = address(cWETH);
        unitrollerProxy.enterMarkets(cTokenAddr);
        cWBTC.borrow(10 ether);
        vm.roll(100000000);
        cWBTC.repayBorrow(cWBTC.borrowBalanceCurrent(compoundBorrower2));

        vm.startPrank(ethHolder1);
        //將cToken利息轉入ETF Contract
        wbtc_weth_eft.claimIntrerstToETF();
        wbtc_weth_eft.redeem(wbtc_weth_eft.balanceOf(ethHolder1));
        //拿回原始數量代幣
        assertEq(wBTC.balanceOf(ethHolder1), 1000 ether);
        assertEq(wETH.balanceOf(ethHolder1), 20000 ether);
        //ethHolder1 claim interest
        wbtc_weth_eft.claim();
        assertGe(wBTC.balanceOf(ethHolder1), 1000 ether);
        assertGe(wETH.balanceOf(ethHolder1), 20000 ether);
        assertEq(wBTC.balanceOf(address(wbtc_weth_eft)), 0);
        assertEq(wETH.balanceOf(address(wbtc_weth_eft)), 0);
     }

    //erc20 testing
    function test_erc20() public {
        _EtfOneUserMint();
        vm.startPrank(ethHolder1);
        wbtc_weth_eft.transfer(ethHolder2, 10000 ether);
        assertEq(wbtc_weth_eft.balanceOf(ethHolder1), 90000 ether);
        assertEq(wbtc_weth_eft.balanceOf(ethHolder2), 10000 ether);

        wbtc_weth_eft.approve(ethHolder2, 10000 ether);
        assertEq(wbtc_weth_eft.allowance(ethHolder1, ethHolder2), 10000 ether);

        vm.startPrank(ethHolder2);
        wbtc_weth_eft.transferFrom(ethHolder1, ethHolder3, 10000 ether);
        assertEq(wbtc_weth_eft.balanceOf(ethHolder1), 80000 ether);
        assertEq(wbtc_weth_eft.balanceOf(ethHolder3), 10000 ether);

    }
    //單一User mint
     function _EtfOneUserMint() public{
        vm.startPrank(ethHolder1);
        deal(address(wBTC), ethHolder1, 1000 ether);
        deal(address(wETH), ethHolder1, 20000 ether);
        ETFErc20InterFace.ETF[] memory etfMint = new ETFErc20InterFace.ETF[](2);

        ETFErc20InterFace.ETF memory WBTCElement = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(0),
                proportion: 1000 ether,
                minimum: 0
            });
        etfMint[0] = WBTCElement;

        ETFErc20InterFace.ETF memory WETHElement = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(0),
                proportion: 20000 ether,
                minimum: 0
            });
        etfMint[1] = WETHElement;
        wBTC.approve(address(wbtc_weth_eft),  1000 ether);
        wETH.approve(address(wbtc_weth_eft),20000 ether);
        wbtc_weth_eft.mint(etfMint);
        assertEq(wbtc_weth_eft.balanceOf(ethHolder1), 100000 ether);
     }
     
     //多user簡單claim利息
    function test_borrow_claim2() public {
        _EtfUsersMint();
        vm.startPrank(compoundBorrower1);
        deal(address(wBTC), compoundBorrower1, 1000 ether);
        deal(address(wETH), compoundBorrower1, 10000 ether);
        wBTC.approve(address(cWBTC), type(uint256).max);
        wETH.approve(address(cWETH), type(uint256).max);
        cWBTC.mint(1000 ether);

        address[] memory cTokenAddr = new address[](1);
        cTokenAddr[0] = address(cWBTC);
        unitrollerProxy.enterMarkets(cTokenAddr);
        cWETH.borrow(100 ether);
        vm.roll(10000000);
        cWETH.repayBorrow(cWETH.borrowBalanceCurrent(compoundBorrower1));

        deal(address(wBTC), compoundBorrower2, 5000 ether);
        deal(address(wETH), compoundBorrower2, 100000 ether);
        vm.startPrank(compoundBorrower2);
        wBTC.approve(address(cWBTC), type(uint256).max);
        wETH.approve(address(cWETH), type(uint256).max);
        cWETH.mint(wETH.balanceOf(compoundBorrower2));
        cTokenAddr[0] = address(cWETH);
        unitrollerProxy.enterMarkets(cTokenAddr);
        cWBTC.borrow(10 ether);
        vm.roll(100000000);
        cWBTC.repayBorrow(cWBTC.borrowBalanceCurrent(compoundBorrower2));

        vm.startPrank(ethHolder1);
        //將cToken利息轉入ETF Contract
        wbtc_weth_eft.claimIntrerstToETF();
        wbtc_weth_eft.redeem(wbtc_weth_eft.balanceOf(ethHolder1));
        //拿回原始數量代幣
        assertEq(wBTC.balanceOf(ethHolder1), 1000 ether);
        assertEq(wETH.balanceOf(ethHolder1), 20000 ether);
        //ethHolder1 claim interest
        wbtc_weth_eft.claim();
        assertGe(wBTC.balanceOf(ethHolder1), 1000 ether);
        assertGe(wETH.balanceOf(ethHolder1), 20000 ether);

        vm.startPrank(ethHolder2);
        //因為間隔要大於約一年
        vm.expectRevert("block number not allow to claim");
        wbtc_weth_eft.claimIntrerstToETF();
        wbtc_weth_eft.redeem(wbtc_weth_eft.balanceOf(ethHolder2));
        //拿回原始數量代幣
        assertEq(wBTC.balanceOf(ethHolder2), 100 ether);
        assertEq(wETH.balanceOf(ethHolder2), 2000 ether);
        //ethHolder2 claim interest
        wbtc_weth_eft.claim();
        assertGe(wBTC.balanceOf(ethHolder2), 100 ether);
        assertGe(wETH.balanceOf(ethHolder2), 2000 ether);
     }

     //多User mint
     function _EtfUsersMint() public{
        vm.startPrank(ethHolder1);
        deal(address(wBTC), ethHolder1, 1000 ether);
        deal(address(wETH), ethHolder1, 20000 ether);
        ETFErc20InterFace.ETF[] memory etfMint = new ETFErc20InterFace.ETF[](2);

        ETFErc20InterFace.ETF memory WBTCElement1 = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(0),
                proportion: 1000 ether,
                minimum: 0
            });
        etfMint[0] = WBTCElement1;

        ETFErc20InterFace.ETF memory WETHElement1 = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(0),
                proportion: 20000 ether,
                minimum: 0
            });
        etfMint[1] = WETHElement1;
        wBTC.approve(address(wbtc_weth_eft),  1000 ether);
        wETH.approve(address(wbtc_weth_eft),20000 ether);
        wbtc_weth_eft.mint(etfMint);
        assertEq(wbtc_weth_eft.balanceOf(ethHolder1), 100000 ether);

        vm.startPrank(ethHolder2);
        deal(address(wBTC), ethHolder2, 100 ether);
        deal(address(wETH), ethHolder2, 2000 ether);

        ETFErc20InterFace.ETF[] memory etfMint2 = new ETFErc20InterFace.ETF[](2);
        ETFErc20InterFace.ETF memory WBTCElement2 = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(0),
                proportion: 100 ether,
                minimum: 0
            });
        etfMint2[0] = WBTCElement2;

        ETFErc20InterFace.ETF memory WETHElement2 = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(0),
                proportion: 2000 ether,
                minimum: 0
            });
        etfMint2[1] = WETHElement2;
        wBTC.approve(address(wbtc_weth_eft),  100 ether);
        wETH.approve(address(wbtc_weth_eft),2000 ether);
        wbtc_weth_eft.mint(etfMint2);
        assertEq(wbtc_weth_eft.balanceOf(ethHolder2), 10000 ether);
     }


    // proxy測試
    function test_proxy() public{
        assertEq(wbtc_weth_eft.VERSION(), "0.0.1");
       
       //proxy update
        ETFErc20v2 eftv2 = new ETFErc20v2();
        wbtc_weth_eft.updateCodeAddress(address(eftv2)
        ,abi.encodeWithSelector(eftv2.v2Initialize.selector));

        assertEq(wbtc_weth_eft.VERSION(), "0.0.2");
    }

}

contract erc20Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}
