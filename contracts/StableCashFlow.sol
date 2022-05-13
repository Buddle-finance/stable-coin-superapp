//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./RedirectTokens.sol";

contract StableCashFlow is RedirectTokens {
    using SafeERC20 for IERC20;

    ISuperToken token1;
    ISuperToken token2;

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken _token1, 
        ISuperToken _token2
    ) RedirectTokens(
            host,
            cfa,
            _token1,
            _token2
        ) public {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(uint256 _amount) public {
        require(token1.balanceOf(msg.sender) > 0, "Not enough balance");
        require(token2.balanceOf(msg.sender) > 0, "Not enough balance");

        token2.transferFrom(msg.sender, address(this), _amount);
        token1.transferFrom(msg.sender, address(this), _amount);

        // TODO: Mint amm tokens to the owner
    }

    function removeLiquidity(uint256 _amount) public {        
        // TODO: Burn amm tokens and transfer value of token 1 and 2 to the owner
    }   

}
