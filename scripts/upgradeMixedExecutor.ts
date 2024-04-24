import {ethers, hardhatArguments, upgrades} from "hardhat";
import {networks} from "./networks";

export async function upgradeMixedExecutor(chainId: bigint) {
    const network = networks[hardhatArguments.network as keyof typeof networks];
    if (network == undefined) {
        throw new Error(`network ${hardhatArguments.network} is not defined`);
    }
    const document = require(`../deployments/${chainId}.json`);

    const MixedExecutor = await ethers.getContractFactory("MixedExecutorUpgradeable");
    const instance = await ethers.getContractAt(
        "MixedExecutorUpgradeable",
        document.deployments.MixedExecutorUpgradeable,
    );
    const newInstance = await upgrades.upgradeProxy(instance, MixedExecutor);
    console.log(`MixedExecutorUpgradeable upgraded at ${await newInstance.getAddress()}`);
}

async function main() {
    await upgradeMixedExecutor((await ethers.provider.getNetwork()).chainId);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
