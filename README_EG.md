## CryptoETF
Many financial sectors have similar ETF-packaged products, which track a certain index through a basket of assets. Similarly, on the Ethereum blockchain, there should be tracking tokens similar to ETFs. However, simply depositing native tokens to mint new ETF tokens and locking the native tokens in a contract without movement is a waste. Therefore, combining Compound to lend out native tokens to earn interest, this protocol can generate transaction fees. Long-term holders can also receive interest rewards and other incentives.

## Direction
In terms of its structure, this product is an ETF portfolio token combined with the Compound v2 lending protocol, enabling users to track indices and receive fixed interest income.

### Structure
![image](https://github.com/aechen1202/CryptoETF/assets/16042619/3aafffc4-0a9c-4694-b664-ab18880ba8b2)


### Role
* Users使用者:參與指數追蹤的一般使用者，可以依指定比例原生Token存入鑄造等比的ETF Token，此ETF Token是個ERC20協議支援ERC20協議功能，使用者可以申請持有期間的利息，如果使用者需要解除此EFT Token也可以註銷此代幣因而獲得原始比例的原生代幣
* admin管理者:管理者負責篩選好品質的原生代幣並且設定既有比例，設定完畢此ETF Token組成的原生代幣與比例則不可變更
### Interface
* mint鑄造:呼叫EFT Contract mint方法並且傳送原生代幣(ig.weth.wbtc)至EFT Contract，EFT Contract會立刻傳入Compound cToken Contract的mint返回對應的cToken存在EFT Contract，EFT Contract會記錄該使用者所屬的cToken與block index等資料

![image](https://github.com/aechen1202/CryptoETF/assets/16042619/258b4eee-094e-43ac-9168-e81cccb020b4)


* claim申請利息:呼叫EFT Contract claim方法獲得原生代幣利息

![image](https://github.com/aechen1202/CryptoETF/assets/16042619/15c69791-56af-4c26-873c-331dcd544870)


* claimIntrerstToETF將利息轉入ETF合約:由使用者呼叫將compound cToken利息轉入ETF合約內，暫定一年左右的block時間間隔可呼叫

![image](https://github.com/aechen1202/CryptoETF/assets/16042619/bfa3d209-8527-4cd0-9609-1f2c5a3dc9bb)



* redeem解除代幣:呼叫EFT Contract redeem解除代幣，使用者會獲得應有比例的原始代幣


![image](https://github.com/aechen1202/CryptoETF/assets/16042619/9cb6d8e1-3dd1-4d80-b1f6-86aaab976024)



* supportEFTMarket支援etf market: admin管理者可使用此方法將部屬好的ETF合約地址在CONTROLLER註冊，不然MINT時候會不通過

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





