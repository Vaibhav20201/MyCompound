const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers")

describe("My Compound", function () {
    let MyCompound, mycompound, user;
    const DAI = "0x6b175474e89094c44da98b954eedeac495271d0f";
    const CDAI = "0x5d3a536e4d6dbd6114cc1ead35777bab948e3643";
    const CETH = "0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5"
    const ACC = "0x9a7a9d980ed6239b89232c012e21f4c210f4bef1";
    beforeEach(async function(){
        MyCompound = await ethers.getContractFactory("MyCompound");
        mycompound = await MyCompound.deploy();
        await mycompound.deployed();
        [user, _] = await ethers.getSigners();
        mycompound.connect(user);
    });
    
    describe("", function(){
        it("Should supply, borrow, payback & withdraw Erc20 tokens", async function(){
            const dai = ethers.utils.parseUnits("0.000001", 18);
            const daib = ethers.utils.parseUnits("0.0000001", 18);
            let cTokenAmount = 3000;
         
            const tokenArtifact = await artifacts.readArtifact("IERC20");
            const token = new ethers.Contract(DAI, tokenArtifact.abi, ethers.provider);
            const tokenWithSigner = token.connect(user);
   
            const cTokenArtifact = await artifacts.readArtifact("CErc20");
            const cToken = new ethers.Contract(CDAI, cTokenArtifact.abi, ethers.provider);
            const cTokenWithSigner = cToken.connect(user);
        
            await network.provider.send("hardhat_setBalance", [
                ACC,
                ethers.utils.parseEther('10.0').toHexString(),
            ]);
          
            await network.provider.send("hardhat_setBalance", [
                user.address,
                ethers.utils.parseEther('10.0').toHexString(),
            ]);
      
            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [ACC],
            });
       
            const signer = await ethers.getSigner(ACC);
      
            await token.connect(signer).transfer(user.address, dai);
          
            await hre.network.provider.request({
                method: "hardhat_stopImpersonatingAccount",
                params: [ACC],
            });
            
            await tokenWithSigner.approve(mycompound.address, dai);
            await mycompound.supplyErc20(DAI, CDAI, dai);
            console.log("Supplied Erc20!")

            await mycompound.borrowErc20(DAI, CDAI, 18, 100000, [CDAI]);
            console.log("Borrowed Erc20!")

            await tokenWithSigner.approve(mycompound.address, 100000);
            await mycompound.paybackErc20(DAI, CDAI, 100000); 
            console.log("Payed Back Erc20!")

            await mycompound.withdrawErc20(DAI, CDAI, cTokenAmount);
            console.log("Withdrawn Erc20!")
            
        }).timeout(100000);

        it("Should supply & withdraw Ether", async function(){
            let cTokenAmount = 3000;

            const cEthArtifact = await artifacts.readArtifact("CEth");
            const cEth = new ethers.Contract(CETH, cEthArtifact.abi, ethers.provider);
            const cEthWithSigner = cEth.connect(user);

            await network.provider.send("hardhat_setBalance", [
                user.address,
                ethers.utils.parseEther('10.0').toHexString(),
            ]);

            await mycompound.supplyEth(CETH, {value: ethers.utils.parseEther('1.0').toHexString()});
            console.log("Supplied Ether!")
            await mycompound.withdrawEth(CETH, cTokenAmount);
            console.log("Withdrawn Ether")
        }).timeout(100000);

        it("Should borrow & payback Ether", async function(){
            const dai = ethers.utils.parseUnits("0.000001", 18);
            const daib = ethers.utils.parseUnits("0.0000001", 18);
            let cTokenAmount = 3000;
         
            const tokenArtifact = await artifacts.readArtifact("IERC20");
            const token = new ethers.Contract(DAI, tokenArtifact.abi, ethers.provider);
            const tokenWithSigner = token.connect(user);
   
            const cTokenArtifact = await artifacts.readArtifact("CErc20");
            const cToken = new ethers.Contract(CDAI, cTokenArtifact.abi, ethers.provider);
            const cTokenWithSigner = cToken.connect(user);
        
            await network.provider.send("hardhat_setBalance", [
                ACC,
                ethers.utils.parseEther('10.0').toHexString(),
            ]);
          
            await network.provider.send("hardhat_setBalance", [
                user.address,
                ethers.utils.parseEther('10.0').toHexString(),
            ]);
      
            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [ACC],
            });
       
            const signer = await ethers.getSigner(ACC);
      
            await token.connect(signer).transfer(user.address, dai);
          
            await hre.network.provider.request({
                method: "hardhat_stopImpersonatingAccount",
                params: [ACC],
            });
            
            await tokenWithSigner.approve(mycompound.address, dai);
            await mycompound.supplyErc20(DAI, CDAI, dai);

            await mycompound.borrowEth(CETH, 18, 100000, [CDAI]);
            console.log("Borrowed Ether!")

            await mycompound.paybackEth(CETH, {value: 100000});
            console.log("Payed Back Ether!")
            
        }).timeout(100000);

    });
});