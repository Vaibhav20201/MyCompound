// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./interfaces/IERC20.sol";
import "./interfaces/compound.sol";

contract MyCompoundErc20 {
    IERC20 public token;
    CErc20 public cToken;

    event Log(string message, uint val);

    constructor(address _token, address _cToken) {
        token = IERC20(_token);
        cToken = CErc20(_cToken);
    }

    function getCTokenBalance() public view returns (uint) {
        return cToken.balanceOf(address(this));
    }

    function supply(uint _amount) external {
        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(address(cToken), _amount);
        require(cToken.mint(_amount) == 0, "mint failed");
        cToken.transferFrom(address(this), msg.sender, getCTokenBalance());
    }

    // not view function
    function getInfo() external returns (uint exchangeRate, uint supplyRate) {
        // Amount of current exchange rate from cToken to underlying
        exchangeRate = cToken.exchangeRateCurrent();
        // Amount added to you supply balance this block
        supplyRate = cToken.supplyRatePerBlock();
    }

    // not view function
    function balanceOfUnderlying() external returns (uint) {
        return cToken.balanceOfUnderlying(address(this));
    }

    function withdraw(uint _cTokenAmount) external {
        cToken.transferFrom(msg.sender, address(this), _cTokenAmount);
        require(cToken.redeem(_cTokenAmount) == 0, "redeem failed");
        // cToken.redeemUnderlying(underlying amount);
    }
}