//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8;

import "hardhat/console.sol";
import "./interfaces/compound.sol";
import "./libraries/SafeUpgradeableERC20.sol";

contract MyCompound {
    using SafeUpgradeableERC20 for IERC20Upgradeable;
    mapping(address => mapping(address => uint256)) UserTokenAmountMap;

    receive() external payable {}

    // supply and withdraw //

    function supplyErc20(address _token, address _cToken, uint _amount) external {
        IERC20Upgradeable token = IERC20Upgradeable(_token);
        CErc20 cToken = CErc20(_cToken);

        token.safeTransferFrom(msg.sender, address(this), _amount);
        token.safeApprove(_cToken, _amount);

        uint256 initialCTokenBalance = cToken.balanceOf(address(this));

        require(cToken.mint(_amount) == 0, "mint failed");

        uint256 finalCTokenBalance = cToken.balanceOf(address(this));

        UserTokenAmountMap[msg.sender][_cToken] += finalCTokenBalance - initialCTokenBalance;
    }

    function supplyEth(address _cToken) external payable {
        CEth cToken = CEth(_cToken);

        uint256 initialCTokenBalance = cToken.balanceOf(address(this));

        cToken.mint{value: msg.value}();

        uint256 finalCTokenBalance = cToken.balanceOf(address(this));

        UserTokenAmountMap[msg.sender][_cToken] += finalCTokenBalance - initialCTokenBalance;
    }

    function withdrawErc20(address _token, address _cToken, uint _cTokenAmount) external {
        IERC20Upgradeable token = IERC20Upgradeable(_token);
        CErc20 cToken = CErc20(_cToken);

        require(UserTokenAmountMap[msg.sender][_cToken] >= _cTokenAmount, "Extra");
    
        require(cToken.approve(_cToken, _cTokenAmount), "Approve Failed");

        require(cToken.redeem(_cTokenAmount) == 0, "redeem failed");

        UserTokenAmountMap[msg.sender][_cToken] -= _cTokenAmount;

        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function withdrawEth(address _cToken, uint _cTokenAmount) external {
        CEth cToken = CEth(_cToken);

        require(UserTokenAmountMap[msg.sender][_cToken] >= _cTokenAmount, "Extra");

        require(cToken.approve(_cToken, _cTokenAmount), "Approve Failed");

        require(cToken.redeem(_cTokenAmount) == 0, "redeem failed");

        UserTokenAmountMap[msg.sender][_cToken] -= _cTokenAmount;

        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }


// ------------------------------------------------------------------------------------------------------------ //


    // borrow and payback //

    Comptroller public comptroller = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    PriceFeed public priceFeed = PriceFeed(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);
   

    // enter market and borrow Erc20
    function borrowErc20(address _tokenToBorrow, address _cTokenToBorrow, uint _decimals, uint _amount, address[] memory cTokens) external {
        // enter market
        // enter the supply market so you can borrow another type of asset
        uint[] memory errors = comptroller.enterMarkets(cTokens);
        for(uint i=0; i<errors.length; i++){
            require(errors[i] == 0, "Comptroller.enterMarkets failed.");
        }

        // check liquidity
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(address(this));
        require(error == 0, "error");
        require(shortfall == 0, "shortfall > 0");
        require(liquidity > 0, "liquidity = 0");

        CErc20 cToken = CErc20(_cTokenToBorrow);
        IERC20Upgradeable token = IERC20Upgradeable(_tokenToBorrow);

        // calculate max borrow
        uint price = priceFeed.getUnderlyingPrice(_cTokenToBorrow);
        // liquidity - USD scaled up by 1e18
        // price - USD scaled up by 1e18
        // decimals - decimals of token to borrow
        uint maxBorrow = (liquidity * (10**_decimals)) / price;

        require(maxBorrow > _amount, "Can't borrow this much!");
        require(cToken.borrow(_amount) == 0, "borrow failed");

        token.safeTransfer(msg.sender, _amount);
    }

    // enter market and borrow Ether
    function borrowEth(address _cTokenToBorrow, uint _decimals, uint _amount, address[] memory cTokens) external payable {
        // enter market
        // enter the supply market so you can borrow another type of asset
        uint[] memory errors = comptroller.enterMarkets(cTokens);
        for(uint i=0; i<errors.length; i++){
            require(errors[i] == 0, "Comptroller.enterMarkets failed.");
        }

        // check liquidity
        (uint error, uint liquidity, uint shortfall) = comptroller.getAccountLiquidity(address(this));
        require(error == 0, "error");
        require(shortfall == 0, "shortfall > 0");
        require(liquidity > 0, "liquidity = 0");

        CEth cToken = CEth(_cTokenToBorrow);

        // calculate max borrow
        uint price = priceFeed.getUnderlyingPrice(_cTokenToBorrow);
        // liquidity - USD scaled up by 1e18
        // price - USD scaled up by 1e18
        // decimals - decimals of token to borrow
        uint maxBorrow = (liquidity * (10**_decimals)) / price;
        require(maxBorrow > _amount, "Can't borrow this much!");
        require(cToken.borrow(_amount) == 0, "borrow failed");
        (bool sent,) = msg.sender.call{value: address(this).balance}("");
        require(sent, "Failed to borrow Ether");
    }

    // payback Erc20
    function paybackErc20(address _tokenBorrowed, address _cTokenBorrowed, uint _amount) external {
        IERC20Upgradeable token = IERC20Upgradeable(_tokenBorrowed);
        CErc20 cToken = CErc20(_cTokenBorrowed);

        token.safeTransferFrom(msg.sender, address(this), _amount);

        token.safeApprove(_cTokenBorrowed, _amount);

        require(cToken.repayBorrow(_amount) == 0, "repay failed");
    }

    // payback Ether
    function paybackEth(address _cTokenBorrowed) external payable {
        CEth(_cTokenBorrowed).repayBorrow{value : msg.value};
    }
}