[中文](README.md) / English

## CryptoETF
Many financial sectors have similar ETF-packaged products, which track a certain index through a basket of assets. Similarly, on the Ethereum blockchain, there should be tracking tokens similar to ETFs. However, simply depositing native tokens to mint new ETF tokens and locking the native tokens in a contract without movement is a waste. Therefore, combining Compound to lend out native tokens to earn interest, this protocol can generate transaction fees. Long-term holders can also receive interest rewards and other incentives.

## Direction
In terms of its structure, this product is an ETF portfolio token combined with the Compound v2 lending protocol, enabling users to track indices and receive fixed interest income.

### Structure
![image](https://github.com/aechen1202/CryptoETF/assets/16042619/3aafffc4-0a9c-4694-b664-ab18880ba8b2)


### Role
* Users: General participants in index tracking can deposit native tokens in a designated proportion to mint corresponding ETF tokens. These ETF tokens are ERC20 protocol compliant, supporting ERC20 functionalities. Users can claim interest during the holding period. If users wish to redeem the ETF tokens, they can also burn them to receive the original proportion of native tokens.
* Admin: The administrator is responsible for curating high-quality native tokens and setting their respective proportions. Once set, the composition and proportions of the native tokens comprising the ETF token cannot be altered.

### Interface
* Mint: The process involves calling the mint method of the ETF contract and transferring native tokens (e.g., WETH, WBTC) to the ETF contract. The ETF contract then immediately sends the corresponding native tokens to the Compound cToken contract to mint cToken. Subsequently, the ETF contract records information such as the user's associated cToken and block index.

![image](https://github.com/aechen1202/CryptoETF/assets/16042619/258b4eee-094e-43ac-9168-e81cccb020b4)


* Interest Claim: To claim interest, one would invoke the claim method of the ETF contract to obtain interest in native tokens.

![image](https://github.com/aechen1202/CryptoETF/assets/16042619/15c69791-56af-4c26-873c-331dcd544870)


* Interest Transfer to ETF: Users call the "claimInterestToETF" function to transfer Compound cToken interest into the ETF contract. This can be called at intervals of approximately one year, based on block time.

![image](https://github.com/aechen1202/CryptoETF/assets/16042619/bfa3d209-8527-4cd0-9609-1f2c5a3dc9bb)



* Redemption: Users call the "redeem" function of the ETF contract to redeem tokens, obtaining the original native tokens in the proportion corresponding to their holdings.幣

![image](https://github.com/aechen1202/CryptoETF/assets/16042619/9cb6d8e1-3dd1-4d80-b1f6-86aaab976024)



* Support ETF Market: Admins can utilize this method to register the deployed ETF contract address in the CONTROLLER. Without this registration, minting may not proceed successfully.

### INTERFACE
ETFErc20InterFace

     struct ETF { 
        address token;
        address cToken;
        uint proportion;
        uint minimum;
    }
    function mint(ETF[] memory inputToken) virtual external returns (uint);
    function redeem(uint redeemETF) virtual external returns (uint);
    function getName() virtual external view returns (string memory);
    function claimIntrerstToETF() virtual external returns (bool);
    function claim() virtual external returns (bool);
    function getDescription() virtual external view returns (string memory);
    function getTokenElement() virtual external view returns (ETF[] memory);
   
    function balanceOf(address account) virtual external view returns (uint256);
    function transfer(address dst, uint amount) virtual external returns (bool);
    function transferFrom(address src, address dst, uint amount) virtual external returns (bool);
    function approve(address spender, uint amount) virtual external returns (bool);
    function allowance(address owner, address spender) virtual external view returns (uint);

    function _setComptroller(ComptrollerInterface newComptroller) virtual public returns (bool);
    function VERSION() external view virtual returns (string memory);

ComptrollerInterface

    function mintETFAllowed(address eftToken) virtual external view returns (uint);
    function _supportEFTMarket(address eftToken) external returns (uint)

## foundry test
git clone https://github.com/aechen1202/CryptoETF.git  
cd CryptoETF  
forge build  
forge test





