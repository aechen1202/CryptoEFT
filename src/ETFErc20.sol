// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;
import "./ComptrollerInterface.sol";
import "./CTokenInterfaces.sol";
import "./ETFErc20InterFace.sol";
import "./ERC20/IERC20.sol";
import "forge-std/console.sol";


contract ETFErc20 is ETFErc20InterFace{
  
    ETF[] public tokenElement;
    
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply;
    string public description;
    mapping (address => uint) internal accountTokens;
    

    address public admin;
    ComptrollerInterface public comptroller;

    constructor(string memory _name, string memory _symbol, string memory _description, ETF[] memory _tokenElement) {
        name = _name;
        symbol = _symbol;
        description = _description;
        admin = msg.sender;
        
        for (uint256 i = 0; i < _tokenElement.length; i++) {
            tokenElement.push(_tokenElement[i]);
        }
       
    }

    function mint(ETF[] memory inputToken) override external returns (uint) {
        //重算
        uint percentage = 0;
        for (uint i = 0; i < inputToken.length; i ++) {
            require(inputToken[i].token == tokenElement[i].token, "must same with tokenElement");
            require(inputToken[i].proportion >= tokenElement[i].minimum, "must greader than minimum");
            if(i == 0){
                percentage = inputToken[i].proportion / tokenElement[i].proportion;
            }
            require(inputToken[i].proportion >= tokenElement[i].proportion * percentage, "error proportion");
            inputToken[i].proportion = tokenElement[i].proportion * percentage;
            inputToken[i].cToken = tokenElement[i].cToken;
        }

        //檢查Call controller
        uint allowed = comptroller.mintETFAllowed(address(this));
        if (allowed != 0) {
            //revert MintComptrollerRejection(allowed);
            revert("not allowed");
        }
        
        //cToken mint
        for (uint i = 0; i < inputToken.length; i ++) {
            IERC20(inputToken[i].token).transferFrom(msg.sender, address(this), inputToken[i].proportion);
            IERC20(inputToken[i].token).approve(inputToken[i].cToken, inputToken[i].proportion);
            CErc20Interface(inputToken[i].cToken).mint(inputToken[i].proportion);
        }

        //mint eftToken
        totalSupply = totalSupply + percentage * 1e18;
        accountTokens[msg.sender] = accountTokens[msg.sender] + percentage * 1e18;

        return percentage * 1e18;
    }

    function redeem(uint redeemETF) override external returns (uint) {
        require(accountTokens[msg.sender] >= redeemETF,"redeem amount exceeds balance");
        for (uint i = 0; i < tokenElement.length; i ++) {
            uint redeemCtoken = redeemETF * tokenElement[i].proportion;
            CErc20Interface(tokenElement[i].cToken).redeem(redeemCtoken);
            //claim interest
            //redeemCtoken+interest

            // transfer to user with interest
            //IERC20(tokenElement[i].token).transfer(msg.sender,redeemCtoken);
        }
        accountTokens[msg.sender] -= redeemETF;
        totalSupply -= redeemETF;
        return accountTokens[msg.sender];
    }

    function getName() override external view returns (string memory) {
        return name;
    }

    function getDescription() override external view returns (string memory) {
        return description;
    }

    function getTokenElement() override external view returns (ETF[] memory) {
        return tokenElement;
    }


    function _setComptroller(ComptrollerInterface newComptroller) override public returns (bool) {
        // Check caller is admin
        if (msg.sender != admin) {
            //revert SetComptrollerOwnerCheck();
            revert("only owner!!");
        }
        // Ensure invoke comptroller.isComptroller() returns true
        require(newComptroller.isComptroller(), "marker method returned false");

        // Set market's comptroller to newComptroller
        comptroller = newComptroller;

        // Emit NewComptroller(oldComptroller, newComptroller)
        //emit NewComptroller(oldComptroller, newComptroller);

        return true;
    }

     function balanceOf(address account) override external view returns (uint256) {
        return accountTokens[account];
    }
}
