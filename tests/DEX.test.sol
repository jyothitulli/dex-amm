const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEX", function() {
    let dex, tokenA, tokenB;
    let owner, addr1, addr2;

    // Helper to handle both Ethers v5 and v6 parseEther
    const parseEth = (val) => ethers.parseEther ? ethers.parseEther(val) : ethers.utils.parseEther(val);

    beforeEach(async function() {
        [owner, addr1, addr2] = await ethers.getSigners();
        
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        tokenA = await MockERC20.deploy("Token A", "TKA");
        tokenB = await MockERC20.deploy("Token B", "TKB");
        
        const DEX = await ethers.getContractFactory("DEX");
        // For Ethers v6, we use tokenA.target. For v5, tokenA.address
        const addrA = tokenA.target || tokenA.address;
        const addrB = tokenB.target || tokenB.address;
        dex = await DEX.deploy(addrA, addrB);
        
        const dexAddr = dex.target || dex.address;

        // Approvals
        await tokenA.approve(dexAddr, parseEth("1000000"));
        await tokenB.approve(dexAddr, parseEth("1000000"));
        await tokenA.connect(addr1).approve(dexAddr, parseEth("1000000"));
        await tokenB.connect(addr1).approve(dexAddr, parseEth("1000000"));
    });

    describe("Liquidity Management", function() {
        it("should allow initial liquidity provision", async function() {
            await expect(dex.addLiquidity(parseEth("100"), parseEth("200")))
                .to.emit(dex, "LiquidityAdded");
        });

        it("should mint correct LP tokens for first provider", async function() {
            await dex.addLiquidity(parseEth("100"), parseEth("400"));
            // sqrt(100*400) = 200
            expect(await dex.liquidity(owner.address)).to.equal(parseEth("200"));
        });

        it("should maintain price ratio on liquidity addition", async function() {
            await dex.addLiquidity(parseEth("100"), parseEth("200"));
            await tokenA.transfer(addr1.address, parseEth("50"));
            await tokenB.transfer(addr1.address, parseEth("50"));
            // Ratio is 1:2. Adding 50:50 should fail.
            await expect(dex.connect(addr1).addLiquidity(parseEth("50"), parseEth("50")))
                .to.be.revertedWith("Incorrect liquidity ratio");
        });

        it("should return correct token amounts on liquidity removal", async function() {
            await dex.addLiquidity(parseEth("100"), parseEth("100"));
            const lpBalance = await dex.liquidity(owner.address);
            await dex.removeLiquidity(lpBalance);
            expect(await dex.reserveA()).to.equal(0);
        });
    });

    describe("Token Swaps", function() {
        beforeEach(async function() {
            await dex.addLiquidity(parseEth("100"), parseEth("200"));
        });

        it("should calculate correct output amount with fee", async function() {
            const out = await dex.getAmountOut(parseEth("10"), parseEth("100"), parseEth("200"));
            // (10 * 0.997 * 200) / (100 + 9.97) = 18.13
            expect(out).to.be.closeTo(parseEth("18.13"), parseEth("0.01"));
        });

        it("should increase k after swap due to fees", async function() {
            const k1 = (await dex.reserveA()) * (await dex.reserveB());
            await dex.swapAForB(parseEth("10"));
            const k2 = (await dex.reserveA()) * (await dex.reserveB());
            expect(k2).to.be.greaterThan(k1);
        });

        it("should emit Swap event", async function() {
            await expect(dex.swapAForB(parseEth("10")))
                .to.emit(dex, "Swap");
        });
    });
});