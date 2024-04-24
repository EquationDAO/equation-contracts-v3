import {ethers, hardhatArguments, upgrades} from "hardhat";
import {networks} from "./networks";
import {getContractAddress, getCreate2Address} from "@ethersproject/address";
import {keccak256} from "@ethersproject/keccak256";
import {encodePacked} from "web3-utils";
import {OrderBookUpgradeable, PositionRouterUpgradeable, RouterUpgradeable} from "../typechain-types";
import {parsePercent} from "./util";

async function main() {
    const network = networks[hardhatArguments.network as keyof typeof networks];
    if (network == undefined) {
        throw new Error(`network ${hardhatArguments.network} is not defined`);
    }

    const deployments = new Map<string, string | {name: string; index: number; market: string}[]>();
    // deploy libraries
    const {configurableUtil, fundingRateUtil, liquidityPositionUtil, marketUtil, positionUtil} =
        await deployLibraries();
    const txReceipt = await configurableUtil.runner!.provider!.getTransactionReceipt(
        (await configurableUtil.deploymentTransaction())!.hash,
    );
    console.log(`First contract deployed at block ${txReceipt!.blockNumber}`);
    deployments.set("ConfigurableUtil", await configurableUtil.getAddress());
    deployments.set("FundingRateUtil", await fundingRateUtil.getAddress());
    deployments.set("LiquidityPositionUtil", await liquidityPositionUtil.getAddress());
    deployments.set("MarketUtil", await marketUtil.getAddress());
    deployments.set("PositionUtil", await positionUtil.getAddress());

    const [deployer] = await ethers.getSigners();
    let nonce = await deployer.getNonce();
    console.log(`deployer address: ${deployer.address}, nonce: ${nonce}`);

    // plugin addresses
    nonce += 1; // skip the implementation contract
    const routerAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    nonce += 1; // skip the implementation contract
    const orderBookAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    nonce += 1; // skip the implementation contract
    const positionRouterAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // price feed address
    nonce += 1; // skip the implementation contract
    const priceFeedAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // market manager address
    const marketDescriptorDeployerAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    const marketIndexerAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    nonce += 1; // skip the implementation contract
    const marketManagerAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // mixed executor address
    nonce += 1; // skip the implementation contract
    const mixedExecutorAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // executor assistant address
    const executorAssistantAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // liquidator address
    nonce += 1; // skip the implementation contract
    const liquidatorAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // farm reward distributor address
    nonce += 1; // skip the implementation contract
    const farmRewardDistributorAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // protocol fee distributor address
    nonce += 1; // skip the implementation contract
    const protocolFeeDistributorAddr = getContractAddress({from: deployer.address, nonce: nonce++});
    // farm reward collector address
    nonce += 1; // skip the implementation contract
    const rewardCollectorAddr = getContractAddress({from: deployer.address, nonce: nonce++});

    deployments.set("RouterUpgradeable", routerAddr);
    deployments.set("OrderBookUpgradeable", orderBookAddr);
    deployments.set("PositionRouterUpgradeable", positionRouterAddr);
    deployments.set("LiquidatorUpgradeable", liquidatorAddr);
    deployments.set("PriceFeedUpgradeable", priceFeedAddr);
    deployments.set("MarketDescriptorDeployer", marketDescriptorDeployerAddr);
    deployments.set("MarketIndexer", marketIndexerAddr);
    deployments.set("MarketManagerUpgradeable", marketManagerAddr);
    deployments.set("MixedExecutorUpgradeable", mixedExecutorAddr);
    deployments.set("ExecutorAssistantUpgradeable", executorAssistantAddr);
    deployments.set("FarmRewardDistributorUpgradeable", farmRewardDistributorAddr);
    deployments.set("ProtocolFeeDistributorUpgradeable", protocolFeeDistributorAddr);
    deployments.set("RewardCollectorUpgradeable", rewardCollectorAddr);

    // deploy plugins
    const Router = await ethers.getContractFactory("RouterUpgradeable");
    const router = await upgrades.deployProxy(Router, [marketManagerAddr]);
    await router.waitForDeployment();
    expectAddr(await router.getAddress(), routerAddr);
    console.log(`Router deployed to: ${await router.getAddress()}`);

    const OrderBook = await ethers.getContractFactory("OrderBookUpgradeable");
    const orderBook = await upgrades.deployProxy(OrderBook, [
        network.usd,
        routerAddr,
        marketManagerAddr,
        network.minOrderBookExecutionFee,
    ]);
    await orderBook.waitForDeployment();
    expectAddr(await orderBook.getAddress(), orderBookAddr);
    console.log(`OrderBook deployed to: ${await orderBook.getAddress()}`);

    const PositionRouter = await ethers.getContractFactory("PositionRouterUpgradeable");
    const positionRouter = await upgrades.deployProxy(PositionRouter, [
        network.usd,
        routerAddr,
        marketManagerAddr,
        network.minPositionRouterExecutionFee,
    ]);
    await positionRouter.waitForDeployment();
    expectAddr(await positionRouter.getAddress(), positionRouterAddr);
    console.log(`PositionRouter deployed to: ${await positionRouter.getAddress()}`);

    // deploy price feed
    const PriceFeed = await ethers.getContractFactory("PriceFeedUpgradeable");
    if (network.ignoreReferencePriceFeedError) {
        console.warn(
            "👿👿ignoreReferencePriceFeedError is set to true, reference price feed error will be ignored👿👿",
        );
    }
    const priceFeed = await upgrades.deployProxy(PriceFeed, [
        network.usdChainLinkPriceFeed,
        0,
        network.ignoreReferencePriceFeedError,
    ]);
    await priceFeed.waitForDeployment();
    expectAddr(await priceFeed.getAddress(), priceFeedAddr);
    console.log(`PriceFeed deployed to: ${await priceFeed.getAddress()}`);

    // deploy market manager
    const MarketDescriptorDeployer = await ethers.getContractFactory("MarketDescriptorDeployer");
    const marketDescriptorDeployer = await MarketDescriptorDeployer.deploy();
    await marketDescriptorDeployer.waitForDeployment();
    expectAddr(await marketDescriptorDeployer.getAddress(), marketDescriptorDeployerAddr);
    console.log(`MarketDescriptorDeployer deployed to: ${await marketDescriptorDeployer.getAddress()}`);

    const MarketIndexer = await ethers.getContractFactory("MarketIndexer");
    const marketIndexer = await MarketIndexer.deploy(marketManagerAddr);
    await marketIndexer.waitForDeployment();
    expectAddr(await marketIndexer.getAddress(), marketIndexerAddr);
    console.log(`MarketIndexer deployed to: ${await marketIndexer.getAddress()}`);

    const MarketManager = await ethers.getContractFactory("MarketManagerUpgradeable", {
        libraries: {
            ConfigurableUtil: await configurableUtil.getAddress(),
            FundingRateUtil: await fundingRateUtil.getAddress(),
            LiquidityPositionUtil: await liquidityPositionUtil.getAddress(),
            MarketUtil: await marketUtil.getAddress(),
            PositionUtil: await positionUtil.getAddress(),
        },
    });
    const marketManager = await upgrades.deployProxy(MarketManager, [
        network.usd,
        protocolFeeDistributorAddr,
        routerAddr,
        network.efc,
    ]);
    await marketManager.waitForDeployment();
    expectAddr(await marketManager.getAddress(), marketManagerAddr);
    console.log(`MarketManager deployed to: ${await marketManager.getAddress()}`);

    // deploy mixed executor
    const MixedExecutor = await ethers.getContractFactory("MixedExecutorUpgradeable");

    const mixedExecutor = await upgrades.deployProxy(MixedExecutor, [
        routerAddr,
        marketIndexerAddr,
        liquidatorAddr,
        positionRouterAddr,
        priceFeedAddr,
        orderBookAddr,
        marketManagerAddr,
    ]);
    await mixedExecutor.waitForDeployment();
    expectAddr(await mixedExecutor.getAddress(), mixedExecutorAddr);
    console.log(`MixedExecutor deployed to: ${await mixedExecutor.getAddress()}`);

    // deploy executor assistant
    const ExecutorAssistant = await ethers.getContractFactory("ExecutorAssistant");
    const executorAssistant = await ExecutorAssistant.deploy(positionRouterAddr);
    await executorAssistant.waitForDeployment();
    expectAddr(await executorAssistant.getAddress(), executorAssistantAddr);
    console.log(`ExecutorAssistant deployed to: ${await executorAssistant.getAddress()}`);

    // deploy liquidator
    const Liquidator = await ethers.getContractFactory("LiquidatorUpgradeable");
    const liquidator = await upgrades.deployProxy(Liquidator, [routerAddr, marketManagerAddr, network.usd]);
    await liquidator.waitForDeployment();
    expectAddr(await liquidator.getAddress(), liquidatorAddr);
    console.log(`Liquidator deployed to: ${await liquidator.getAddress()}`);

    // deploy farm reward distributor
    const FarmRewardDistributor = await ethers.getContractFactory("FarmRewardDistributorUpgradeable");
    const farmRewardDistributor = await upgrades.deployProxy(FarmRewardDistributor, [
        network.equ,
        network.feeDistributor,
        network.farmRewardDistributorV2,
        network.efc,
    ]);
    await farmRewardDistributor.waitForDeployment();
    expectAddr(await farmRewardDistributor.getAddress(), farmRewardDistributorAddr);
    console.log(`FarmRewardDistributor deployed to: ${await farmRewardDistributor.getAddress()}`);

    // deploy protocol fee distributor
    const ProtocolFeeDistributor = await ethers.getContractFactory("ProtocolFeeDistributorUpgradeable");
    const protocolFeeDistributor = await upgrades.deployProxy(ProtocolFeeDistributor, [
        network.feeDistributor,
        network.efc,
        network.usd,
        await (await ethers.getContractAt("IFarmRewardDistributorV2", network.farmRewardDistributorV2)).signer(),
    ]);
    await protocolFeeDistributor.waitForDeployment();
    expectAddr(await protocolFeeDistributor.getAddress(), protocolFeeDistributorAddr);
    console.log(`ProtocolFeeDistributor deployed to: ${await protocolFeeDistributor.getAddress()}`);

    // deploy reward collector
    const RewardCollector = await ethers.getContractFactory("RewardCollectorUpgradeable");
    const rewardCollector = await upgrades.deployProxy(RewardCollector, [
        network.routerV1,
        farmRewardDistributorAddr,
        network.farmRewardDistributorV2,
        protocolFeeDistributorAddr,
    ]);
    await rewardCollector.waitForDeployment();
    expectAddr(await rewardCollector.getAddress(), rewardCollectorAddr);
    console.log(`RewardCollector deployed to: ${await rewardCollector.getAddress()}`);

    // initialize plugins
    await router.registerLiquidator(liquidatorAddr);
    await router.registerPlugin(liquidator); // liquidator is also a plugin
    await router.registerPlugin(orderBookAddr);
    await router.registerPlugin(positionRouterAddr);
    await router.registerPlugin(rewardCollectorAddr);
    await router.registerPlugin(mixedExecutorAddr); // mixed executor is also a plugin
    await orderBook.updateOrderExecutor(mixedExecutorAddr, true);
    await positionRouter.updatePositionExecutor(mixedExecutorAddr, true);
    await liquidator.updateExecutor(mixedExecutorAddr, true);
    console.log("Initialize plugins finished");

    // register markets
    const MarketDescriptor = await ethers.getContractFactory("MarketDescriptor");
    const marketDescriptorInitCodeHash = keccak256(MarketDescriptor.bytecode);
    let markets = [];
    let index = 1;
    for (let item of network.markets) {
        await marketDescriptorDeployer.deploy(item.name);
        const marketAddr = getCreate2Address(
            marketDescriptorDeployerAddr,
            keccak256(encodePacked(item.name)!),
            marketDescriptorInitCodeHash,
        );
        await marketManager.enableMarket(marketAddr, {
            baseConfig: item.marketCfg.baseCfg,
            feeRateConfig: item.marketCfg.feeRateCfg,
            priceConfig: item.marketCfg.priceCfg,
        });
        await marketIndexer.assignMarketIndex(marketAddr);
        if (item.chainLinkPriceFeed != undefined) {
            await priceFeed.setRefPriceFeed(marketAddr, item.chainLinkPriceFeed);
            await priceFeed.setMaxCumulativeDeltaDiffs(marketAddr, item.maxCumulativeDeltaDiff);
        } else {
            console.warn(`👿👿${item.name} chainLinkPriceFeed is not set👿👿`);
        }

        markets.push({
            name: item.name,
            index: index++,
            market: marketAddr,
        });
    }
    deployments.set("registerMarkets", markets);

    // initialize price feed
    await priceFeed.setUpdater(mixedExecutorAddr, true);
    if (network.sequencerUptimeFeed != undefined) {
        await priceFeed.setSequencerUptimeFeed(network.sequencerUptimeFeed);
    } else {
        console.warn("👿👿sequencerUptimeFeed is not set👿👿");
    }
    await marketManager.setPriceFeed(priceFeedAddr);
    console.log("Initialize price feed finished");

    // initialize liquidator
    await liquidator.updatePriceFeed();
    console.log("Initialize liquidator finished");

    // initialize mixed executor
    for (let item of network.mixedExecutors) {
        await mixedExecutor.setExecutor(item, true);
    }
    console.log("Initialize mixed executor finished");

    const [contractsV2Gov, contractsV1Gov] = await ethers.getSigners();

    // initialize farm reward distributor
    const multiMinter = await ethers.getContractAt("IMultiMinter", network.equ);
    await multiMinter.connect(contractsV1Gov).setMinter(farmRewardDistributorAddr, true);
    console.log("Initialize farm reward distributor finished");

    // initialize reward collector
    await farmRewardDistributor.setCollector(rewardCollectorAddr, true);
    const routerV1 = await ethers.getContractAt("IPluginManager", network.routerV1);
    await routerV1.connect(contractsV1Gov).registerPlugin(rewardCollectorAddr);
    const farmRewardDistributorV2 = await ethers.getContractAt(
        "IFarmRewardDistributorV2",
        network.farmRewardDistributorV2,
    );
    await farmRewardDistributorV2.connect(contractsV1Gov).setCollector(rewardCollector, true);
    await farmRewardDistributorV2.connect(contractsV1Gov).setRewardType(21, "LiquidityV3");
    await farmRewardDistributorV2.connect(contractsV1Gov).setRewardType(22, "ProfitMarginV3");
    await farmRewardDistributorV2.connect(contractsV1Gov).setRewardType(23, "ReferralProfitMarginV3");
    console.log("Initialize reward collector finished");

    // initialize protocol fee distributor
    await protocolFeeDistributor.setCollector(rewardCollectorAddr, true);
    await protocolFeeDistributor.setCampaignRate(network.campaignRate);

    // write deployments to file
    const deploymentsOutput = {
        block: txReceipt!.blockNumber,
        usd: network.usd,
        efc: network.efc,
        marketDescriptorInitCodeHash: marketDescriptorInitCodeHash,
        deployments: Object.fromEntries(deployments),
    };
    const fs = require("fs");
    if (!fs.existsSync("deployments")) {
        fs.mkdirSync("deployments");
    }
    const chainId = (await configurableUtil.runner!.provider!.getNetwork()).chainId;
    fs.writeFileSync(`deployments/${chainId}.json`, JSON.stringify(deploymentsOutput, null, 4));
    console.log(`💾 deployments output to deployments/${chainId}.json`);
}

function expectAddr(actual: string, expected: string) {
    if (actual != expected) {
        throw new Error(`actual address ${actual} is not equal to expected address ${expected}`);
    }
}

async function deployLibraries() {
    const ConfigurableUtil = await ethers.getContractFactory("ConfigurableUtil");
    const configurableUtil = await ConfigurableUtil.deploy();

    const FundingRateUtil = await ethers.getContractFactory("FundingRateUtil");
    const fundingRateUtil = await FundingRateUtil.deploy();

    const LiquidityPositionUtil = await ethers.getContractFactory("LiquidityPositionUtil");
    const liquidityPositionUtil = await LiquidityPositionUtil.deploy();

    const MarketUtil = await ethers.getContractFactory("MarketUtil");
    const marketUtil = await MarketUtil.deploy();

    const PositionUtil = await ethers.getContractFactory("PositionUtil");
    const positionUtil = await PositionUtil.deploy();

    await configurableUtil.waitForDeployment();
    await fundingRateUtil.waitForDeployment();
    await liquidityPositionUtil.waitForDeployment();
    await marketUtil.waitForDeployment();
    await positionUtil.waitForDeployment();

    console.log(`ConfigurableUtil deployed to: ${await configurableUtil.getAddress()}`);
    console.log(`FundingRateUtil deployed to: ${await fundingRateUtil.getAddress()}`);
    console.log(`LiquidityPositionUtil deployed to: ${await liquidityPositionUtil.getAddress()}`);
    console.log(`MarketUtil deployed to: ${await marketUtil.getAddress()}`);
    console.log(`PositionUtil deployed to: ${await positionUtil.getAddress()}`);

    return {configurableUtil, fundingRateUtil, liquidityPositionUtil, marketUtil, positionUtil};
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
