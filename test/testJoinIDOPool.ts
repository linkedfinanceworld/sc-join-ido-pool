import { expect } from "chai";
import { ethers } from "hardhat";

import {Contract, BigNumber, Wallet} from "ethers";
import { formatEther } from "ethers/lib/utils";
import {MockProvider, deployContract} from 'ethereum-waffle';
import {createFixtureLoader} from 'ethereum-waffle';
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

describe("LFWIDOPoolToken", function () {

    const provider = new MockProvider();
    const [wallet] = provider.getWallets();

    const loadFixture = createFixtureLoader([wallet], provider);
    const etherUnit = BigNumber.from(10).pow(18);

    async function fixture([wallet]: Wallet[], _mockProvider: MockProvider) {
        const [owner, user1, user2] = await ethers.getSigners();

        const JoinIDOPool = await ethers.getContractFactory("JoinIDOPool");
        const idoPool = await JoinIDOPool.deploy();
        await idoPool.deployed();

        const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
        const tokenBUSD = await ERC20Mock.deploy("BUSD", "BUSD" , owner.address, BigNumber.from(100000).mul(etherUnit));
        await tokenBUSD.deployed();


        // console.log("wallet.address: ", wallet.address);
        console.log("tokenBUSD.address: ", tokenBUSD.address);
        console.log("idoPool.address: ", idoPool.address);
        console.log("owner.address: ", owner.address);
        console.log("user1.address: ", user1.address);
        console.log("user2.address: ", user2.address);


        console.log("initalize LFW Staking Pool");
        const startBlock = await ethers.provider.getBlockNumber();
        const duration = 10*86400/3; // number of blocks in 10 days
        const endBlock = await ethers.provider.getBlockNumber() + duration;
        const maxPoolAllocation = 10000;
        idoPool.connect(owner).setConfig(tokenBUSD.address, startBlock, endBlock,  maxPoolAllocation, owner.address);

        return {owner, user1, user2, tokenBUSD, idoPool};
    }

    let owner: SignerWithAddress
    let user1: SignerWithAddress
    let user2: SignerWithAddress
    let tokenBUSD: Contract
    let idoPool: Contract

    beforeEach(async function() {
        const _fixture = await loadFixture(fixture);
        owner = _fixture.owner;
        user1 = _fixture.user1;
        user2 = _fixture.user2;
        tokenBUSD = _fixture.tokenBUSD;
        idoPool = _fixture.idoPool;
    });

    describe("Testsuite 1", function () {
        it ("TC1 - owner can add & remove whitelist", async function () {     
            await idoPool.connect(owner).addWhitelistAddress([user1.address, user2.address]);
            await idoPool.connect(owner).removeWhitelistAddress([user2.address]);
            await idoPool.connect(owner).addWhitelistAddress([user2.address]);
         });

        it ("TC2 - normal user cannot modify whitelist", async function () {
            await expect(idoPool.connect(user1).addWhitelistAddress([user1.address]))
                .to.be.revertedWith("Ownable: caller is not the owner");
            await expect(idoPool.connect(user1).removeWhitelistAddress([user2.address]))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

        it ("TC3 - verify owner sets max allocation", async function () {
            const addresses = [user1.address, user2.address];
            const maxAllocationList = [200, 400];
            await idoPool.connect(owner).addUserMaxAllocation(addresses, maxAllocationList);

            //TODO revert if length of addresses & maxAllocationList are different
            await expect(idoPool.connect(owner).addUserMaxAllocation(addresses, [100]))
                .to.be.revertedWith("Length of addresses and allocation values are different");
        });
    
        

        
    });

    describe("Testsuite 2", function () {
        it ("tc1", async function () {
            
        });
    });

});
