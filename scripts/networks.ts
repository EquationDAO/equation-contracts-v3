import {ethers} from "hardhat";
import {parsePercent} from "./util";

const defaultBaseCfg = {
    minMarginPerLiquidityPosition: 10n * 10n ** 6n,
    maxLeveragePerLiquidityPosition: 100n,
    liquidationFeeRatePerLiquidityPosition: parsePercent("0.05%"),
    minMarginPerPosition: 10n * 10n ** 6n,
    maxLeveragePerPosition: 200n,
    liquidationFeeRatePerPosition: parsePercent("0.5%"),
    maxPositionLiquidity: 10_000_000n * 10n ** 6n,
    maxPositionValueRate: parsePercent("100%"),
    maxSizeRatePerPosition: parsePercent("20%"),
    liquidationExecutionFee: 800_000n, // 0.8 USD
};

const defaultFeeRateCfg = {
    protocolFundingFeeRate: parsePercent("0.016%"),
    fundingCoeff: parsePercent("100%"),
    protocolFundingCoeff: parsePercent("75%"),
    interestRate: parsePercent("0.01%"),
    fundingBuffer: parsePercent("0.05%"),
    liquidityFundingFeeRate: parsePercent("25%"),
};

const defaultPriceCfg = {
    maxPriceImpactLiquidity: (1n << 128n) - 1n,
    liquidationVertexIndex: 6,
    dynamicDepthMode: 0,
    dynamicDepthLevel: parsePercent("70%"),
    vertices: [
        {balanceRate: 0, premiumRate: 0},
        {balanceRate: parsePercent("0.5%"), premiumRate: parsePercent("0.05%")},
        {balanceRate: parsePercent("2.5%"), premiumRate: parsePercent("0.1%")},
        {balanceRate: parsePercent("5%"), premiumRate: parsePercent("0.15%")},
        {balanceRate: parsePercent("6%"), premiumRate: parsePercent("0.2%")},
        {balanceRate: parsePercent("7%"), premiumRate: parsePercent("0.3%")},
        {balanceRate: parsePercent("8%"), premiumRate: parsePercent("0.4%")},
        {balanceRate: parsePercent("9%"), premiumRate: parsePercent("0.5%")},
        {balanceRate: parsePercent("10%"), premiumRate: parsePercent("0.6%")},
        {balanceRate: parsePercent("50%"), premiumRate: parsePercent("10%")},
    ],
};

const _100xCfg = {
    baseCfg: {
        ...defaultBaseCfg,
        maxLeveragePerLiquidityPosition: 200n,
        maxLeveragePerPosition: 100n,
        liquidationFeeRatePerPosition: parsePercent("0.4%"),
        maxPositionLiquidity: 25_000_000n * 10n ** 6n,
        maxPositionValueRate: parsePercent("3000%"),
        maxSizeRatePerPosition: parsePercent("0.667%"),
    },
    feeRateCfg: {
        ...defaultFeeRateCfg,
    },
    priceCfg: {
        ...defaultPriceCfg,
        liquidationVertexIndex: 6,
        maxPriceImpactLiquidity: 25_000_000n * 10n ** 6n,
        dynamicDepthLevel: parsePercent("20%"),
    },
};

const _20xCfg = {
    baseCfg: {
        ...defaultBaseCfg,
        maxLeveragePerLiquidityPosition: 100n,
        maxLeveragePerPosition: 20n,
        liquidationFeeRatePerPosition: parsePercent("1%"),
        maxPositionLiquidity: 3_000_000n * 10n ** 6n,
        maxPositionValueRate: parsePercent("1000%"),
        maxSizeRatePerPosition: parsePercent("2%"),
    },
    feeRateCfg: {
        ...defaultFeeRateCfg,
    },
    priceCfg: {
        ...defaultPriceCfg,
        maxPriceImpactLiquidity: 3_000_000n * 10n ** 6n,
        liquidationVertexIndex: 6,
        dynamicDepthLevel: parsePercent("40%"),
        vertices: [
            {balanceRate: 0, premiumRate: 0},
            {balanceRate: parsePercent("1%"), premiumRate: parsePercent("0.05%")},
            {balanceRate: parsePercent("3%"), premiumRate: parsePercent("0.1%")},
            {balanceRate: parsePercent("5%"), premiumRate: parsePercent("0.15%")},
            {balanceRate: parsePercent("6%"), premiumRate: parsePercent("0.2%")},
            {balanceRate: parsePercent("9%"), premiumRate: parsePercent("0.6%")},
            {balanceRate: parsePercent("12%"), premiumRate: parsePercent("1%")},
            {balanceRate: parsePercent("20%"), premiumRate: parsePercent("2.5%")},
            {balanceRate: parsePercent("28%"), premiumRate: parsePercent("4%")},
            {balanceRate: parsePercent("50%"), premiumRate: parsePercent("10%")},
        ],
    },
};

const _10xCfg = {
    baseCfg: {
        ...defaultBaseCfg,
        maxLeveragePerLiquidityPosition: 100n,
        maxLeveragePerPosition: 10n,
        liquidationFeeRatePerPosition: parsePercent("2.5%"),
        maxPositionLiquidity: 700_000n * 10n ** 6n,
        maxPositionValueRate: parsePercent("400%"),
        maxSizeRatePerPosition: parsePercent("5%"),
    },
    feeRateCfg: {
        ...defaultFeeRateCfg,
    },
    priceCfg: {
        ...defaultPriceCfg,
        liquidationVertexIndex: 7,
        maxPriceImpactLiquidity: 700_000n * 10n ** 6n,
        dynamicDepthLevel: parsePercent("60%"),
        vertices: [
            {balanceRate: 0, premiumRate: 0},
            {balanceRate: parsePercent("1%"), premiumRate: parsePercent("0.05%")},
            {balanceRate: parsePercent("3%"), premiumRate: parsePercent("0.1%")},
            {balanceRate: parsePercent("5%"), premiumRate: parsePercent("0.15%")},
            {balanceRate: parsePercent("6%"), premiumRate: parsePercent("0.2%")},
            {balanceRate: parsePercent("9%"), premiumRate: parsePercent("0.6%")},
            {balanceRate: parsePercent("12%"), premiumRate: parsePercent("1%")},
            {balanceRate: parsePercent("20%"), premiumRate: parsePercent("2.5%")},
            {balanceRate: parsePercent("28%"), premiumRate: parsePercent("4%")},
            {balanceRate: parsePercent("50%"), premiumRate: parsePercent("10%")},
        ],
    },
};

const defaultMaxCumulativeDeltaDiff = 100n * 1000n; // 10%

export const networks = {
    "arbitrum-sepolia": {
        usd: "0x130a10D76E53eC70C2d1c05e9C2EcfB5C3350fe0",
        usdChainLinkPriceFeed: "0x80EDee6f667eCc9f63a0a6f55578F870651f06A4",
        minPositionRouterExecutionFee: ethers.parseUnits("0.0001", "ether"),
        minOrderBookExecutionFee: ethers.parseUnits("0.00013", "ether"),
        sequencerUptimeFeed: undefined,
        ignoreReferencePriceFeedError: true,
        equ: "0x70Ad55cD2A18D8A49A330114EF9A1c378454Fab8",
        efc: "0xE4687B2675d487ddab1244993f92bA7b46CF86C0",
        routerV1: "0xbEB81D003CB2E0a334196E8E462fD1fD7EA5a868",
        feeDistributor: "0x01D588a5F7f67f02F68f750e2C4d10A791C6F035",
        farmRewardDistributorV2: "0x616806f08789628C8aA61Ab4f7c0f0c903ECFF7a",
        campaignRate: parsePercent("33.33%"),
        markets: [
            {
                name: "ETH",
                chainLinkPriceFeed: "0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: _100xCfg.baseCfg,
                    feeRateCfg: _100xCfg.feeRateCfg,
                    priceCfg: _100xCfg.priceCfg,
                },
            },
            {
                name: "BTC",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._100xCfg.baseCfg,
                        maxLeveragePerPosition: 200,
                        liquidationFeeRatePerPosition: parsePercent("0.2%"),
                        maxPositionLiquidity: 35_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: {
                        ..._100xCfg.feeRateCfg,
                        tradingFeeRate: parsePercent("0.01%"),
                        referralDiscountRate: parsePercent("0%"),
                    },
                    priceCfg: {
                        ..._100xCfg.priceCfg,
                        liquidationVertexIndex: 4,
                        maxPriceImpactLiquidity: 35_000_000n * 10n ** 6n,
                        dynamicDepthLevel: parsePercent("0%"),
                    },
                },
            },
            {
                name: "SOL",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: _20xCfg.baseCfg,
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: _20xCfg.priceCfg,
                },
            },
            {
                name: "ARB",
                chainLinkPriceFeed: "0xD1092a65338d049DB68D7Be6bD89d17a0929945e",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_200_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_200_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "OP",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_200_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_200_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "MATIC",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_200_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_200_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "AVAX",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_200_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_200_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "LINK",
                chainLinkPriceFeed: "0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_200_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_200_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "ORDI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_200_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_200_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "DOGE",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_500_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_500_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "XRP",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 2_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 2_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "ADA",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_500_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_500_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "BNB",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 2_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 2_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "LTC",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 2_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 2_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "ETC",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_500_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_500_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "FIL",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SUI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "TIA",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "DOT",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "BLUR",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "INJ",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SEI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "TRB",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "ATOM",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "APT",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "NEAR",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "LDO",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "DYDX",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "MKR",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "STX",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "FTM",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "RUNE",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "UNI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "CRV",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "1000BONK",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "ENS",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "AAVE",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "1000PEPE",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "MINA",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "JTO",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "RDNT",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SUSHI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "1INCH",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SNX",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "PENDLE",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "NTRN",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "PYTH",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "GMX",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
        ],
        mixedExecutors: ["0x8D2b663E72A8e29C771e9d0985d313bdd817BB28", "0xe78E0EC237996CF4965623ed6d474acE5Fd36301"],
    },
    "arbitrum-mainnet": {
        usd: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
        usdChainLinkPriceFeed: "0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7",
        minPositionRouterExecutionFee: ethers.parseUnits("0.0003", "ether"),
        minOrderBookExecutionFee: ethers.parseUnits("0.0004", "ether"),
        sequencerUptimeFeed: "0xFdB631F5EE196F0ed6FAa767959853A9F217697D",
        ignoreReferencePriceFeedError: true,
        equ: "0x87AAfFdF26c6885f6010219208D5B161ec7609c0",
        efc: "0xe6bf4e8A735d4F83a662d5aD430159Aa97eAE37E",
        routerV1: "0x911a71DDa951958913219f7cBD7e4a297ca52B3B",
        feeDistributor: "0x3C77EEB8eC4716a6389a522eD590FbbD261ABE8e",
        farmRewardDistributorV2: "0x93d4f6ADA5686eaf51bA78ECDAc34A9292B8D7d2",
        campaignRate: parsePercent("33.33%"),
        markets: [
            {
                name: "ETH",
                chainLinkPriceFeed: "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._100xCfg.baseCfg,
                        maxPositionLiquidity: 25_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: _100xCfg.feeRateCfg,
                    priceCfg: {
                        ..._100xCfg.priceCfg,
                        maxPriceImpactLiquidity: 25_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "BTC",
                chainLinkPriceFeed: "0x6ce185860a4963106506C203335A2910413708e9",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._100xCfg.baseCfg,
                        maxLeveragePerPosition: 200,
                        liquidationFeeRatePerPosition: parsePercent("0.2%"),
                        maxPositionLiquidity: 25_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: {
                        ..._100xCfg.feeRateCfg,
                        tradingFeeRate: parsePercent("0.01%"),
                        referralDiscountRate: parsePercent("0%"),
                    },
                    priceCfg: {
                        ..._100xCfg.priceCfg,
                        liquidationVertexIndex: 4,
                        maxPriceImpactLiquidity: 25_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "SOL",
                chainLinkPriceFeed: "0x24ceA4b8ce57cdA5058b924B9B9987992450590c",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: _20xCfg.baseCfg,
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: _20xCfg.priceCfg,
                },
            },
            {
                name: "ARB",
                chainLinkPriceFeed: "0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _20xCfg,
            },
            {
                name: "OP",
                chainLinkPriceFeed: "0x205aaD468a11fd5D34fA7211bC6Bad5b3deB9b98",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _20xCfg,
            },
            {
                name: "MATIC",
                chainLinkPriceFeed: "0x52099D4523531f678Dfc568a7B1e5038aadcE1d6",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _20xCfg,
            },
            {
                name: "AVAX",
                chainLinkPriceFeed: "0x8bf61728eeDCE2F32c456454d87B5d6eD6150208",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _20xCfg,
            },
            {
                name: "LINK",
                chainLinkPriceFeed: "0x86E53CF1B870786351Da77A57575e79CB55812CB",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _20xCfg,
            },
            {
                name: "ORDI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _20xCfg,
            },
            {
                name: "DOGE",
                chainLinkPriceFeed: "0x9A7FB1b3950837a8D9b40517626E11D4127C098C",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_500_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_500_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "XRP",
                chainLinkPriceFeed: "0xB4AD57B52aB9141de9926a3e0C8dc6264c2ef205",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 2_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 2_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "ADA",
                chainLinkPriceFeed: "0xD9f615A9b820225edbA2d821c4A696a0924051c6",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_500_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_500_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "BNB",
                chainLinkPriceFeed: "0x6970460aabF80C5BE983C6b74e5D06dEDCA95D4A",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 2_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 2_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "LTC",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 2_000_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 2_000_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "ETC",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: {
                    baseCfg: {
                        ..._20xCfg.baseCfg,
                        maxPositionLiquidity: 1_500_000n * 10n ** 6n,
                    },
                    feeRateCfg: _20xCfg.feeRateCfg,
                    priceCfg: {
                        ..._20xCfg.priceCfg,
                        maxPriceImpactLiquidity: 1_500_000n * 10n ** 6n,
                    },
                },
            },
            {
                name: "FIL",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SUI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "TIA",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "DOT",
                chainLinkPriceFeed: "0xa6bC5bAF2000424e90434bA7104ee399dEe80DEc",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "BLUR",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "INJ",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SEI",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "TRB",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "ATOM",
                chainLinkPriceFeed: "0xCDA67618e51762235eacA373894F0C79256768fa",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "APT",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "NEAR",
                chainLinkPriceFeed: "0xBF5C3fB2633e924598A46B9D07a174a9DBcF57C0",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "LDO",
                chainLinkPriceFeed: "0xA43A34030088E6510FecCFb77E88ee5e7ed0fE64",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "DYDX",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "MKR",
                chainLinkPriceFeed: "0xdE9f0894670c4EFcacF370426F10C3AD2Cdf147e",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "STX",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "FTM",
                chainLinkPriceFeed: "0xFeaC1A3936514746e70170c0f539e70b23d36F19",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "RUNE",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "UNI",
                chainLinkPriceFeed: "0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "CRV",
                chainLinkPriceFeed: "0xaebDA2c976cfd1eE1977Eac079B4382acb849325",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "1000BONK",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "ENS",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "AAVE",
                chainLinkPriceFeed: "0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "1000PEPE",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "MINA",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "JTO",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "RDNT",
                chainLinkPriceFeed: "0x20d0Fcab0ECFD078B036b6CAf1FaC69A6453b352",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SUSHI",
                chainLinkPriceFeed: "0xb2A8BA74cbca38508BA1632761b56C897060147C",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "1INCH",
                chainLinkPriceFeed: "0x4bC735Ef24bf286983024CAd5D03f0738865Aaef",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "SNX",
                chainLinkPriceFeed: "0x054296f0D036b95531B4E14aFB578B80CFb41252",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "PENDLE",
                chainLinkPriceFeed: "0x66853E19d73c0F9301fe099c324A1E9726953433",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "NTRN",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "PYTH",
                chainLinkPriceFeed: undefined,
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
            {
                name: "GMX",
                chainLinkPriceFeed: "0xDB98056FecFff59D032aB628337A4887110df3dB",
                maxCumulativeDeltaDiff: defaultMaxCumulativeDeltaDiff,
                marketCfg: _10xCfg,
            },
        ],
        mixedExecutors: ["0x587C4526d4134cad229E8beA5007ACf30Dc7e8Dd", "0xE6d7Ccc73e0F7E1063E2204ffFA7742CC25E3B38"],
    },
};
