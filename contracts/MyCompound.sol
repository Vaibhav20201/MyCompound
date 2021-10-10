// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./interfaces/compound.sol";

contract MyCompound {

    function supplyErc20(address _token, address _cToken, uint _amount) external {
        IERC20 token = IERC20(_token);
        CErc20 cToken = CErc20(_cToken);
        token.transferFrom(msg.sender, address(this), _amount);
        token.approve(address(cToken), _amount);
        require(cToken.mint(_amount) == 0, "mint failed");
        cToken.transferFrom(address(this), msg.sender, cToken.balanceOf(address(this)));
    }

    function supplyEth(address _cToken) external payable {
        CEth cToken = CEth(_cToken);
        cToken.mint{value: msg.value}();
        cToken.transferFrom(address(this), msg.sender, cToken.balanceOf(address(this)));
    }

    function withdrawErc20(address _cToken, uint _cTokenAmount) external {
        CErc20 cToken = CErc20(_cToken);
        cToken.transferFrom(msg.sender, address(this), _cTokenAmount);
        require(cToken.redeem(_cTokenAmount) == 0, "redeem failed");
    }

    function withdrawEth(address _cToken, uint _cTokenAmount) external {
        CEth cToken = CEth(_cToken);
        cToken.transferFrom(msg.sender, address(this), _cTokenAmount);
        require(cToken.redeem(_cTokenAmount) == 0, "redeem failed");
    }

    // borrow and repay //
    Comptroller public comptroller = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    PriceFeed public priceFeed = PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

    // collateral
    function getCollateralFactor(address _cToken) external view returns (uint) {
        (, uint colFactor,) = comptroller.markets(_cToken);
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
    function borrow(address _tokenToBorrow, address _cTokenToBorrow, uint _decimals, uint _amount, address[] memory cTokens) external {
        // enter market
        // enter the supply market so you can borrow another type of asset
        uint[] memory errors = comptroller.enterMarkets(cTokens);
        for(uint i=0; i<errors.length; i++){
            require(errors[0] == 0, "Comptroller.enterMarkets failed.");
        }

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
        require(maxBorrow > _amount, "Can't borrow this much!");
        require(CErc20(_cTokenToBorrow).borrow(_amount) == 0, "borrow failed");
        IERC20(_tokenToBorrow).transferFrom(address(this), msg.sender, _amount);
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