//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./RedirectTokens.sol";

contract StableCashFlow is RedirectTokens {
    using SafeERC20 for IERC20;

    address token1;
    address token2;

    bool isInitilize = false;
    function initilize(address _token1, address _token2) public {
        require(!isInitilize);

        token1 = _token1;
        token2 = _token2;
        isInitilize = true;
    }

    function addToken1Liquidity(uint256 _amount) public {
        require(isInitilize);
        require(IERC20(token1).balanceOf(msg.sender) > 0, "Not enough balance");

        IERC20(token1).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function addToken2Liquidity(uint256 _amount) public {
        require(isInitilize);
        require(IERC20(token2).balanceOf(msg.sender) > 0, "Not enough balance");

        IERC20(token2).safeTransferFrom(msg.sender, address(this), _amount);
    }

}
