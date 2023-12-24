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
        ETFErc20InterFace.ETF[] memory ETFList = new ETFErc20InterFace.ETF[](2);

        ETFErc20InterFace.ETF memory WBTCElement = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(cWBTC),
                proportion: 10000,
                minimum: 1000
            });
        ETFList[0] = WBTCElement;

        ETFErc20InterFace.ETF memory WETHElement = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(cWETH),
                proportion: 10000,
                minimum: 1000
            });
        ETFList[1] = WETHElement;

        wbtc_weth_eft = new ETFErc20("wbtc_weth_eft", "wbtc_weth_eft",  "wbtc_weth_eft", ETFList);
        wbtc_weth_eft._setComptroller(unitrollerProxy);
        //可以supportEFTMarket條件對應的cToken地址都需要supportMarket
        uint code = unitrollerProxy._supportEFTMarket(address(wbtc_weth_eft));
        console2.log(code);
        assertEq(code, 0);
    }

    function test_mint() public {
        vm.startPrank(user1);
        deal(address(wBTC), user1, 100 ether);
        deal(address(wETH), user1, 100 ether);
        ETFErc20InterFace.ETF[] memory etfMint = new ETFErc20InterFace.ETF[](2);

        ETFErc20InterFace.ETF memory WBTCElement = ETFErc20InterFace.ETF(
            {
                token: address(wBTC),
                cToken: address(cWBTC),
                proportion: 10000,
                minimum: 1000
            });
        etfMint[0] = WBTCElement;

        ETFErc20InterFace.ETF memory WETHElement = ETFErc20InterFace.ETF(
            {
                token: address(wETH),
                cToken: address(cWETH),
                proportion: 10000,
                minimum: 1000
            });
        etfMint[1] = WETHElement;
        wBTC.approve(address(wbtc_weth_eft), 10000);
        wETH.approve(address(wbtc_weth_eft), 10000);
        uint i =wbtc_weth_eft.mint(etfMint);
        console2.log(i);
    }
}

contract erc20Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }
}
