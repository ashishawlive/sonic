const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Token contract", function () {
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();
    await token.deployed();
    const owner = await token.owner();
    const ownerBalance = await token.balanceOf(owner);
    expect(await token.totalSupply()).to.equal(ownerBalance);
  });
});

describe("Token contract", function () {
  it("Should transfer tokens between accounts", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();

    await token.deployed();

    // Transfer 50 tokens from owner to addr1
    await token.transfer(addr1.address, 50);
    expect(await token.balanceOf(addr1.address)).to.equal(50);

    // Transfer 50 tokens from addr1 to addr2
    await token.connect(addr1).transfer(addr2.address, 50);
    expect(await token.balanceOf(addr2.address)).to.equal(50);
  });
});

describe("Token contract", function () {
  it("Should fail if sender doesn’t have enough tokens", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();

    await token.deployed();

    const initialOwnerBalance = await token.balanceOf(owner.address);

    // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
    // `require` will evaluate false and revert the transaction.
    await expect(token.connect(addr1).transfer(owner.address, 1)).to.be.revertedWith(
      "ERC20: transfer amount exceeds balance"
    );

    // Owner balance shouldn't have changed.
    expect(await token.balanceOf(owner.address)).to.equal(initialOwnerBalance);
  });
});

describe("Token contract", function () {
  it("Should update balances after transfers", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();

    await token.deployed();

    const initialOwnerBalance = await token.balanceOf(owner.address);

    // Transfer 100 tokens from owner to addr1.
    await token.transfer(addr1.address, 100);

    // Transfer another 50 tokens from owner to addr2.
    await token.transfer(addr2.address, 50);

    // Check balances.
    const finalOwnerBalance = await token.balanceOf(owner.address);
    expect(finalOwnerBalance).to.equal(initialOwnerBalance - 150);

    const addr1Balance = await token.balanceOf(addr1.address);
    expect(addr1Balance).to.equal(100);

    const addr2Balance = await token.balanceOf(addr2.address);
    expect(addr2Balance).to.equal(50);
  });
});

describe("Token contract", function () {
  it("Should emit transfer event", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();

    await token.deployed();

    // Transfer 100 tokens from owner to addr1.
    await expect(token.transfer(addr1.address, 100))
      .to.emit(token, "Transfer")
      .withArgs(owner.address, addr1.address, 100);

    // Transfer another 50 tokens from owner to addr2.
    await expect(token.transfer(addr2.address, 50))
      .to.emit(token, "Transfer")
      .withArgs(owner.address, addr2.address, 50);
  });
});

describe("Token contract", function () {
  it("Should fail if sender doesn’t have enough tokens", async function () {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("Token");
    const token = await Token.deploy();

    await token.deployed();

    // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
    // `require` will evaluate false and revert the transaction.
    await expect(token.connect(addr1).transfer(owner.address, 1)).to.be.revertedWith(
      "ERC20: transfer amount exceeds balance"
    );
  });
});