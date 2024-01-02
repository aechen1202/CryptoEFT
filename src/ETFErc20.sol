// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;
import "./ComptrollerInterface.sol";
import "./CTokenInterfaces.sol";
import "./ETFErc20InterFace.sol";
import "./ERC20/IERC20.sol";
import "forge-std/console.sol";


contract ETFErc20 is ETFErc20InterFace{
  
    ETF[] public tokenElement;
    uint mantissa = 1e18;
    
    //erc20
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint public totalSupply;
    string public description;
    mapping (address => uint) internal accountTokens;
    // Approved token transfer amounts on behalf of others
    mapping (address => mapping (address => uint)) internal transferAllowances;
    
    //interest
    uint interestBlockPrior = 2102400;
    struct interest { 
        address token;
        uint interest;
    }
    struct interestBlock { 
        interest[] tokenInterest;
        uint totalSupply;
        uint blockNumber;
    }
    interestBlock[] interestHistory;
    address[] holders;
    mapping(address=>mapping(address=>uint)) interestBalance;
    uint interestBlockIndex = 0;

    //admin
    address public admin;
    ComptrollerInterface public comptroller;
    bool _notEntered;

    constructor(string memory _name, string memory _symbol, string memory _description, ETF[] memory _tokenElement) {
        name = _name;
        symbol = _symbol;
        description = _description;
        admin = msg.sender;
        interestBlockIndex = block.number;
        _notEntered = true;
        
        for (uint256 i = 0; i < _tokenElement.length; i++) {
            tokenElement.push(_tokenElement[i]);
        }
       
    }

    /**
     * @notice Sender supplies assets into the etf package market and receives etf token base on component ratio
     * @param inputToken Amount of reduction to reserves
     * @return uint the number of etf token sender's mint
    */
    function mint(ETF[] memory inputToken) override external nonReentrant returns (uint) {
        //Recalculate
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

        //Call controller to check
        uint allowed = comptroller.mintETFAllowed(address(this));
        if (allowed != 0) {
            revert("not allowed");
        }
        
        //cToken mint
        for (uint i = 0; i < inputToken.length; i ++) {
            IERC20(inputToken[i].token).transferFrom(msg.sender, address(this), inputToken[i].proportion);
            IERC20(inputToken[i].token).approve(inputToken[i].cToken, inputToken[i].proportion);
            uint code = CErc20Interface(inputToken[i].cToken).mint(inputToken[i].proportion);
            require( code == 0 , "cToken mint error");
        }

        //mint eftToken
        totalSupply = totalSupply + percentage * mantissa;
        accountTokens[msg.sender] = accountTokens[msg.sender] + percentage * mantissa;
        holders.push(msg.sender);

        emit Mint(msg.sender, inputToken, percentage * mantissa);
        return percentage * mantissa;
    }

    /**
     * @notice Sender redeems etf token for the underlying asset base on component ratio
     * @param redeemETF The number of etf token to redeem into underlying
     * @return uint Sender balance after redeem
    */
    function redeem(uint redeemETF) override external nonReentrant returns (uint) {
        require(accountTokens[msg.sender] >= redeemETF,"redeem amount exceeds balance");
        for (uint i = 0; i < tokenElement.length; i ++) {
            uint redeemCtoken = (redeemETF * tokenElement[i].proportion) / mantissa;
            uint code = CErc20Interface(tokenElement[i].cToken).redeemUnderlying(redeemCtoken);
            require( code == 0 , "cToken redeemUnderlying error");
            // transfer to user
            IERC20(tokenElement[i].token).transfer(msg.sender,redeemCtoken);
        }
        accountTokens[msg.sender] -= redeemETF;
        
        totalSupply -= redeemETF;
        
        emit Redeem(msg.sender, redeemETF);
        return accountTokens[msg.sender];
    }

    /**
     * @notice Claim all intrerst from cToken to ETF contract
     * @return bool true=success
    */
    function claimIntrerstToETF() override external nonReentrant returns (bool) {
        require((block.number-interestBlockIndex)>=interestBlockPrior,"block number not allow to claim");
        //interestHistory
        interestBlock storage _interestBlock = interestHistory.push();
        _interestBlock.blockNumber = block.number;
        _interestBlock.totalSupply = totalSupply;

        for (uint i = 0; i < tokenElement.length; i ++) {
            uint tokenBalanceBefore = IERC20(tokenElement[i].token).balanceOf(address(this));
            uint redeemCtoken =  CTokenInterface(tokenElement[i].cToken).balanceOf(address(this));
            //redeem all token back to get interest
            uint code = CErc20Interface(tokenElement[i].cToken).redeem(redeemCtoken);
            require(code==0,"cToken redeem fail");
            
            //mint same amount underlying token to cToken 
            uint actualMintAmount = (tokenElement[i].proportion * totalSupply) / mantissa;
            IERC20(tokenElement[i].token).approve(tokenElement[i].cToken, actualMintAmount);
            code = CErc20Interface(tokenElement[i].cToken).mint(actualMintAmount);
            require(code==0,"cToken mint fail");

            //get balance increase amount
            uint tokenBalanceAfter = IERC20(tokenElement[i].token).balanceOf(address(this));
            uint tokenBalance = tokenBalanceAfter - tokenBalanceBefore;

            //set interestHistory
            interest memory _interest = interest(
            {
                token: tokenElement[i].token,
                interest: tokenBalance
            });
            _interestBlock.tokenInterest.push(_interest);
        }

        //calculate all user interest
        calculateUserInterest();

        emit ClaimIntrerstToETF(msg.sender);

        return true;
    }

    function calculateUserInterest() internal returns (bool) {
        for (uint i = 0; i < holders.length; i ++) {
           if(accountTokens[holders[i]]>0){
            for(uint j = 0; j < interestHistory[interestHistory.length-1].tokenInterest.length; j++){
                address token = interestHistory[interestHistory.length-1].tokenInterest[j].token;
                uint interest = interestHistory[interestHistory.length-1].tokenInterest[j].interest;
                uint totalSupply = interestHistory[interestHistory.length-1].totalSupply;
                uint blockNumber = interestHistory[interestHistory.length-1].blockNumber;
            
                interestBalance[holders[i]][token] = interestBalance[holders[i]][token] + ((interest * accountTokens[holders[i]]) / (totalSupply));
            }

           }
           
        }
        return true;
    }


    /**
     * @notice Claim intrerst to sender
     * @return bool true=success
    */
    function claim() override external nonReentrant returns (bool) {
        for (uint i = 0; i < tokenElement.length; i ++) {
            if(interestBalance[msg.sender][tokenElement[i].token] > 0){
                uint claimBalance = interestBalance[msg.sender][tokenElement[i].token];
                interestBalance[msg.sender][tokenElement[i].token] = 0;
                IERC20(tokenElement[i].token).transfer(msg.sender,claimBalance);
            }
        }

        emit Claim(msg.sender);

        return true;
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

    function balanceOf(address account) override external view returns (uint256) {
        return accountTokens[account];
    }

     /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint256 amount) override external nonReentrant returns (bool) {
        return transferTokens(msg.sender, msg.sender, dst, amount);
    }

      /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint256 amount) override external nonReentrant returns (bool) {
        return transferTokens(msg.sender, src, dst, amount);
    }

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
     * @dev Called by both `transfer` and `transferFrom` internally
     * @param spender The address of the account performing the transfer
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokens The number of tokens to transfer
     * @return 0 if the transfer succeeded, else revert
     */
    function transferTokens(address spender, address src, address dst, uint tokens) internal returns (bool) {
        /* Do not allow self-transfers */
        if (src == dst) {
            revert("Do not allow self-transfers");
        }

        /* Get the allowance, infinite for the account owner */
        uint startingAllowance = 0;
        if (spender == src) {
            startingAllowance = type(uint).max;
        } else {
            startingAllowance = transferAllowances[src][spender];
        }

        /* Do the calculations, checking for {under,over}flow */
        uint allowanceNew = startingAllowance - tokens;
        uint srcTokensNew = accountTokens[src] - tokens;
        uint dstTokensNew = accountTokens[dst] + tokens;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        accountTokens[src] = srcTokensNew;
        accountTokens[dst] = dstTokensNew;

        /* Eat some of the allowance (if necessary) */
        if (startingAllowance != type(uint).max) {
            transferAllowances[src][spender] = allowanceNew;
        }

        /* We emit a Transfer event */
        emit Transfer(src, dst, tokens);

        return true;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (uint256.max means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) override external returns (bool) {
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent (-1 means infinite)
     */
    function allowance(address owner, address spender) override external view returns (uint256) {
        return transferAllowances[owner][spender];
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

    /*** Reentrancy Guard ***/

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }
}
