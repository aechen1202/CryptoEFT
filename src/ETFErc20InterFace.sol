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
    function getDescription() virtual external view returns (string memory);

    function getTokenElement() virtual external view returns (ETF[] memory);


    function _setComptroller(ComptrollerInterface newComptroller) virtual public returns (bool);

    function balanceOf(address account) virtual external view returns (uint256);
}