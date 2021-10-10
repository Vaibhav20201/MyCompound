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

    // borrow and repay //
    Comptroller public comptroller =
        Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    PriceFeed public priceFeed = PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

    // collateral
    function getCollateralFactor() external view returns (uint) {
        (, uint colFactor,) = comptroller.markets(
        address(cToken)
        );
        return colFactor; // divide by 1e18 to get in %
    }

    // account liquidity - calculate how much can I borrow?
    // sum of (supplied balance of market entered * col factor) - borrowed
    function getAccountLiquidity()
        external
        view
        returns (uint liquidity, uint shortfall)
    {
        // liquidity and shortfall in USD scaled up by 1e18
        (uint error, uint _liquidity, uint _shortfall) = comptroller.getAccountLiquidity(
        address(this)
        );
        require(error == 0, "error");
        // normal circumstance - liquidity > 0 and shortfall == 0
        // liquidity > 0 means account can borrow up to `liquidity`
        // shortfall > 0 is subject to liquidation, you borrowed over limit
        return (_liquidity, _shortfall);
    }

    // open price feed - USD price of token to borrow
    function getPriceFeed(address _cToken) external view returns (uint) {
        // scaled up by 1e18
        return priceFeed.getUnderlyingPrice(_cToken);
    }

    // enter market and borrow
    function borrow(address _tokenToBorrow, address _cTokenToBorrow, uint _decimals, uint x) external {
        require(x<100);
        // enter market
        // enter the supply market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        uint[] memory errors = comptroller.enterMarkets(cTokens);
        require(errors[0] == 0, "Comptroller.enterMarkets failed.");

        // check liquidity
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(
        address(this)
        );
        require(error == 0, "error");
        require(shortfall == 0, "shortfall > 0");
        require(liquidity > 0, "liquidity = 0");

        // calculate max borrow
        uint price = priceFeed.getUnderlyingPrice(_cTokenToBorrow);

        // liquidity - USD scaled up by 1e18
        // price - USD scaled up by 1e18
        // decimals - decimals of token to borrow
        uint maxBorrow = (liquidity * (10**_decimals)) / price;
        require(maxBorrow > 0, "max borrow = 0");
        // This contract borrows x% of the max borrow
        // borrow x% of max borrow
        uint amount = (maxBorrow * x) / 100;
        require(CErc20(_cTokenToBorrow).borrow(amount) == 0, "borrow failed");
        IERC20(_tokenToBorrow).transferFrom(address(this), msg.sender, amount);
    }

    // borrowed balance (includes interest)
    // not view function
    function getBorrowedBalance(address _cTokenBorrowed) public returns (uint) {
        return CErc20(_cTokenBorrowed).borrowBalanceCurrent(address(this));
    }

    // borrow rate
    function getBorrowRatePerBlock(address _cTokenBorrowed) external view returns (uint) {
        // scaled up by 1e18
        return CErc20(_cTokenBorrowed).borrowRatePerBlock();
    }

    // payback borrow
    function payback(
        address _tokenBorrowed,
        address _cTokenBorrowed,
        uint _amount
    ) external {
        IERC20(_tokenBorrowed).transferFrom(msg.sender, address(this), _amount);
        IERC20(_tokenBorrowed).approve(_cTokenBorrowed, _amount);
        require(CErc20(_cTokenBorrowed).repayBorrow(_amount) == 0, "repay failed");
    }
}