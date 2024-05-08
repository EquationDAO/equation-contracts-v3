import {networks} from "./networks";

export async function mergeMarkets() {
    const sourceNetworkStr = "arbitrum-sepolia";
    const targetNetworkStr = "arbitrum-mainnet";

    const sourceNetwork = networks[sourceNetworkStr];
    const targetNetwork = networks[targetNetworkStr];
    if (sourceNetwork == undefined) {
        throw new Error(`network ${sourceNetworkStr} is not defined`);
    }
    if (targetNetwork == undefined) {
        throw new Error(`network ${targetNetworkStr} is not defined`);
    }

    if (sourceNetwork.markets.length < targetNetwork.markets.length) {
        throw new Error(`source network has fewer markets than target network`);
    }

    let targetIndex = 0;
    let targetMarketsNew = [];
    for (let i = 0; i < sourceNetwork.markets.length; i++) {
        const sourceMarket = sourceNetwork.markets[i];
        const targetMarket = targetNetwork.markets[targetIndex];
        let targetMarketNew = undefined;
        if (sourceMarket.name === targetMarket.name) {
            targetIndex++;
            targetMarketNew = {
                ...sourceMarket,
                chainLinkPriceFeed: targetMarket.chainLinkPriceFeed,
            };
        } else {
            targetMarketNew = {
                ...sourceMarket,
            };
        }
        targetMarketsNew.push(targetMarketNew);
    }

    const util = require("node:util");
    const output = util.inspect(targetMarketsNew, {depth: null});
    const fs = require("fs");
    fs.writeFileSync(`cache/merge.txt`, output);
}

async function main() {
    mergeMarkets();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
