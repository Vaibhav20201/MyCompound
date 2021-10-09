// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./interfaces/compound.sol";

contract MyCompoundEth {
    CEth public cToken;

    constructor(address _cToken) {
        cToken = CEth(_cToken);
    }

    receive() external payable {
        // React to receiving ether
    }

    function getCTokenBalance() public view returns (uint) {
        return cToken.balanceOf(address(this));
    }

    function supply() external payable {
        cToken.mint{value: msg.value}();
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