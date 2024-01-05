pragma solidity ^0.8.0;
import "./ComptrollerInterface.sol";
abstract contract ETFErc20InterFace{
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

    
    /**
     * @notice Event emitted when tokens are minted
    */
    event Mint(address indexed minter, ETF[] tokens, uint amount);

    /**
     * @notice Event emitted when tokens are redeemed
    */
    event Redeem(address indexed redeemer, uint redeemAmount);

    /**
     * @notice Event emitted claim tokens to ETF contract
    */
    event ClaimIntrerstToETF(address indexed cliamer);

    /**
     * @notice Event emitted claim tokens to user
    */
    event Claim(address indexed cliamer);
   
    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(address indexed owner, address indexed spender, uint amount);

     /**
     * @notice Event emitted when comptroller is changed
     */
    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);

    
}