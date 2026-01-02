const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEX AMM Protocol Full Suite", function () {
  let dex, tokenA, tokenB, owner, addr1;
  const TOKENS_100 = ethers.utils.parseEther("100");
  const TOKENS_50 = ethers.utils.parseEther("50");
  const TOKENS_10 = ethers.utils.parseEther("10");
  const ZERO = 0;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MockERC20");
    tokenA = await Token.deploy("Token A", "TKA");
    tokenB = await Token.deploy("Token B", "TKB");
    const DEX = await ethers.getContractFactory("DEX");
    dex = await DEX.deploy(tokenA.address, tokenB.address);

    await tokenA.approve(dex.address, ethers.constants.MaxUint256);
    await tokenB.approve(dex.address, ethers.constants.MaxUint256);
    await tokenA.transfer(addr1.address, TOKENS_100);
    await tokenB.transfer(addr1.address, TOKENS_100);
    await tokenA.connect(addr1).approve(dex.address, ethers.constants.MaxUint256);
    await tokenB.connect(addr1).approve(dex.address, ethers.constants.MaxUint256);
  });

  describe("1. Initial State", function () {
    it("T1: Should have correct Token A address", async () => expect(await dex.tokenA()).to.equal(tokenA.address));
    it("T2: Should have correct Token B address", async () => expect(await dex.tokenB()).to.equal(tokenB.address));
    it("T3: Reserve A should start at 0", async () => expect(await dex.reserveA()).to.equal(0));
    it("T4: Reserve B should start at 0", async () => expect(await dex.reserveB()).to.equal(0));
    it("T5: Initial LP total supply should be 0", async () => expect(await dex.totalSupply()).to.equal(0));
  });

  describe("2. Liquidity Logic", function () {
    it("T6: Should mint sqrt(a*b) LP tokens on first deposit", async () => {
      await dex.addLiquidity(TOKENS_100, TOKENS_100);
      expect(await dex.balanceOf(owner.address)).to.equal(TOKENS_100);
    });
    it("T7: Should allow second provider to add liquidity proportionally", async () => {
      await dex.addLiquidity(TOKENS_100, TOKENS_100);
      await dex.connect(addr1).addLiquidity(TOKENS_50, TOKENS_50);
      expect(await dex.balanceOf(addr1.address)).to.equal(TOKENS_50);
    });
    it("T8: Should fail if amountA is 0", async () => await expect(dex.addLiquidity(0, TOKENS_100)).to.be.reverted);
    it("T9: Should fail if amountB is 0", async () => await expect(dex.addLiquidity(TOKENS_100, 0)).to.be.reverted);
    it("T10: Should update reserves after multiple deposits", async () => {
      await dex.addLiquidity(TOKENS_100, TOKENS_100);
      expect(await dex.reserveA()).to.equal(TOKENS_100);
    });
  });

  describe("3. Swapping Math & Fees", function () {
    beforeEach(async () => await dex.addLiquidity(TOKENS_100, TOKENS_100));

    it("T11: getAmountOut should apply 0.3% fee correctly", async () => {
      const out = await dex.getAmountOut(TOKENS_10, TOKENS_100, TOKENS_100);
      expect(out).to.equal("9066108938801491315");
    });
    it("T12: swapAforB should reduce reserveB", async () => {
      await dex.swapAforB(TOKENS_10);
      expect(await dex.reserveB()).to.be.lt(TOKENS_100);
    });
    it("T13: swapAforB should increase reserveA", async () => {
      await dex.swapAforB(TOKENS_10);
      expect(await dex.reserveA()).to.equal(ethers.utils.parseEther("110"));
    });
    it("T14: swapBforA should work correctly", async () => {
      await dex.swapBforA(TOKENS_10);
      expect(await dex.reserveA()).to.be.lt(TOKENS_100);
    });
    it("T15: Swap should emit Swap event", async () => {
      await expect(dex.swapAforB(TOKENS_10)).to.emit(dex, "Swap");
    });
    it("T16: Should revert swap if amount is 0", async () => {
      await expect(dex.swapAforB(0)).to.be.reverted;
    });
    it("T17: Should maintain constant product (k) with fee growth", async () => {
      const kBefore = (await dex.reserveA()).mul(await dex.reserveB());
      await dex.swapAforB(TOKENS_10);
      const kAfter = (await dex.reserveA()).mul(await dex.reserveB());
      expect(kAfter).to.be.gt(kBefore);
    });
  });

  describe("4. Liquidity Removal", function () {
    beforeEach(async () => await dex.addLiquidity(TOKENS_100, TOKENS_100));

    it("T18: Should allow removing all liquidity", async () => {
      const lpBalance = await dex.balanceOf(owner.address);
      await dex.removeLiquidity(lpBalance);
      expect(await dex.totalSupply()).to.equal(0);
    });
    it("T19: Should return correct amounts of tokens", async () => {
      const lpHalf = (await dex.balanceOf(owner.address)).div(2);
      await dex.removeLiquidity(lpHalf);
      expect(await dex.reserveA()).to.equal(TOKENS_50);
    });
    it("T20: Should emit LiquidityRemoved event", async () => {
      await expect(dex.removeLiquidity(TOKENS_10)).to.emit(dex, "LiquidityRemoved");
    });
    it("T21: Should fail if LP amount is 0", async () => {
      await expect(dex.removeLiquidity(0)).to.be.reverted;
    });
    it("T22: Should fail if burning more than balance", async () => {
      const tooMuch = (await dex.balanceOf(owner.address)).add(1);
      await expect(dex.removeLiquidity(tooMuch)).to.be.reverted;
    });
  });

  describe("5. Edge Cases & Security", function () {
    it("T23: Should fail swap if reserves are empty", async () => {
      await expect(dex.swapAforB(TOKENS_10)).to.be.revertedWith("Invalid reserves");
    });
    it("T24: LP tokens should have 18 decimals", async () => {
      expect(await dex.decimals()).to.equal(18);
    });
    it("T25: LP token name should be correct", async () => {
      expect(await dex.name()).to.equal("DEX LP Token");
    });
    it("T26: Should handle very small swaps", async () => {
        await dex.addLiquidity(TOKENS_100, TOKENS_100);
        await expect(dex.swapAforB(1000)).to.not.be.reverted;
    });
    it("T27: Total supply should update correctly after multiple removals", async () => {
        await dex.addLiquidity(TOKENS_100, TOKENS_100);
        await dex.removeLiquidity(TOKENS_50);
        expect(await dex.totalSupply()).to.equal(TOKENS_50);
    });
  });

  // Section 7 MOVED INSIDE the main block
  describe("7. Additional Coverage & Edge Cases", function () {
    it("T28: Should handle square root of small numbers (Coverage Fix)", async () => {
      await dex.addLiquidity(2, 2); 
      expect(await dex.totalSupply()).to.be.gt(0);
    });

    it("T29: Should revert if getPrice is called on empty pool", async () => {
      const Token = await ethers.getContractFactory("MockERC20");
      const tA = await Token.deploy("A", "A");
      const tB = await Token.deploy("B", "B");
      const emptyDex = await (await ethers.getContractFactory("DEX")).deploy(tA.address, tB.address);
      await expect(emptyDex.getPrice()).to.be.revertedWith("Empty pool");
    });

    it("T30: Should test min function with different values", async () => {
      await dex.addLiquidity(TOKENS_100, TOKENS_100);
      await dex.connect(addr1).addLiquidity(TOKENS_50, TOKENS_100);
      expect(await dex.reserveB()).to.equal(ethers.utils.parseEther("200"));
    });
  });

}); // End of Full Suite