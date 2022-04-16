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


        console.log("initalize JoinIDOPool");
        const blockNumber = await ethers.provider.getBlockNumber();
        const startTime = (await ethers.provider.getBlock(blockNumber)).timestamp;
        const duration = 7*86400; // 7 days
        const endTime = startTime + duration;
        const maxPoolAllocation = BigNumber.from(1000).mul(etherUnit);
        console.log("startTime:", startTime);
        console.log("endTime: ", endTime);
        idoPool.connect(owner).setConfig(tokenBUSD.address, startTime, endTime,  maxPoolAllocation, owner.address);

        // tokenLFW approve user
        await tokenBUSD.connect(user1).approve(idoPool.address, BigNumber.from(100000).mul(etherUnit))
        await tokenBUSD.connect(user2).approve(idoPool.address, BigNumber.from(100000).mul(etherUnit))

        // have users own 2000 BUSD tokens
        await tokenBUSD.transfer(user1.address, BigNumber.from(2000).mul(etherUnit));
        await tokenBUSD.transfer(user2.address, BigNumber.from(2000).mul(etherUnit));
        const userTokenBalance1 = await tokenBUSD.balanceOf(user1.address);
        const userTokenBalance2 = await tokenBUSD.balanceOf(user2.address);
        console.log("The amount of LFW that the user1 owns: ", formatEther(userTokenBalance1));
        console.log("The amount of LFW that the user2 owns: ", formatEther(userTokenBalance2));


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
            const maxAllocationList = [BigNumber.from(200).mul(etherUnit), BigNumber.from(400).mul(etherUnit)];
            await idoPool.connect(owner).addUserMaxAllocation(addresses, maxAllocationList);

            //TODO revert if length of addresses & maxAllocationList are different
            await expect(idoPool.connect(owner).addUserMaxAllocation(addresses, [100]))
                .to.be.revertedWith("Length of addresses and allocation values are different");
        });

        it ("TC4 - user joins IDO Pool - positive cases", async function () {
            await idoPool.connect(user1).join(BigNumber.from(100).mul(etherUnit));
            await idoPool.connect(user2).join(BigNumber.from(100).mul(etherUnit));
        });

        it ("TC5 - verify cases that users cannot join IDO Pool (exceed amount, not whitelisted))", async function () {
            // exceed total the amount of pool
            await expect(idoPool.connect(user1).join(BigNumber.from(300).mul(etherUnit)))
                .to.be.revertedWith("Exceed the amount to join IDO");

            await idoPool.connect(owner).removeWhitelistAddress([user2.address]);
            await expect(idoPool.connect(user2).join(BigNumber.from(300).mul(etherUnit)))
                .to.be.revertedWith("You are not whitelisted");
            await idoPool.connect(owner).addWhitelistAddress([user2.address]);

            await idoPool.connect(owner).changeMaxPoolAllocation(BigNumber.from(150).mul(etherUnit))
            await expect(idoPool.connect(user2).join(BigNumber.from(100).mul(etherUnit)))
                .to.be.revertedWith("Exceed max pool allocation for this IDO");

            // change it back to the previous value
            await idoPool.connect(owner).changeMaxPoolAllocation(BigNumber.from(1000).mul(etherUnit))

        });




    });

    describe("Testsuite 2", function () {
        it ("tc1", async function () {

        });
    });

});
