// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.23;

import "forge-std/Test.sol";
import {LONG, SHORT} from "../../contracts/types/Side.sol";
import "../../contracts/test/MockPriceFeed.sol";
import "../../contracts/libraries/FundingRateUtil.sol";

contract FundingRateUtilTest is Test {
    IMarketManager.State state;

    MockPriceFeed priceFeed = new MockPriceFeed();
    IConfigurable.MarketConfig marketConfig;

    struct BaseRateCase {
        string name;
        uint128 longSize;
        uint128 shortSize;
        uint160 priceX96;
        uint64 timeDelta;
        uint128 liquidity;
        uint128 minPriceImpactLiquidity;
        int192 want;
    }

    function setUp() public {
        priceFeed.setMaxPriceX96(1 << 96);
        priceFeed.setMinPriceX96(1 << 95);

        state.protocolFee = 1000;
        state.globalPosition = IMarketPosition.GlobalPosition({
            longSize: 0,
            shortSize: 0,
            maxSize: 0,
            maxSizePerPosition: 0,
            longFundingRateGrowthX96: 1,
            shortFundingRateGrowthX96: 1,
            lastFundingFeeSettleTime: uint64(block.timestamp)
        });
        state.globalLiquidityPosition = IMarketLiquidityPosition.GlobalLiquidityPosition({
            netSize: 0,
            liquidationBufferNetSize: 0,
            previousSPPriceX96: 0,
            side: LONG,
            liquidity: 10000000e6,
            unrealizedPnLGrowthX64: 0
        });

        marketConfig.feeRateConfig = IConfigurable.MarketFeeRateConfig({
            protocolFundingFeeRate: 16000, // 0.00016
            fundingCoeff: 1e8, // 1
            protocolFundingCoeff: 75e6, // 0.75
            interestRate: 10000, // 0.0001
            fundingBuffer: 50000, // 0.0005
            liquidityFundingFeeRate: 5e7 // 0.5
        });
        marketConfig.priceConfig.maxPriceImpactLiquidity = state.globalLiquidityPosition.liquidity;
    }

    function test_calculateFundingRateX96() public view {
        (uint256 longFundingRateX96, uint256 shortFundingRateX96) = FundingRateUtil.calculateFundingRateX96(
            marketConfig.feeRateConfig,
            0
        );
        vm.assertEq(longFundingRateX96, 0);
        vm.assertEq(shortFundingRateX96, 0);

        (longFundingRateX96, shortFundingRateX96) = FundingRateUtil.calculateFundingRateX96(
            marketConfig.feeRateConfig,
            60
        );
        vm.assertEq(longFundingRateX96, 19807040628566084398386);
        vm.assertEq(shortFundingRateX96, 6602346876188694799462);
    }

    function testFuzz_calculateFundingRateX96(uint64 _timeDelta) public view {
        (uint256 longFundingRateX96, uint256 shortFundingRateX96) = FundingRateUtil.calculateFundingRateX96(
            marketConfig.feeRateConfig,
            _timeDelta
        );
        uint256 maxValue = 1 << 146;
        vm.assertTrue(longFundingRateX96 >= 0);
        vm.assertTrue(shortFundingRateX96 >= 0);
        vm.assertTrue(longFundingRateX96 <= maxValue);
        vm.assertTrue(shortFundingRateX96 <= maxValue);
    }

    function testFuzz_calculateBaseRateX96(
        uint128 _longSize,
        uint128 _shortSize,
        uint128 _premiumRateX96,
        uint64 _timeDelta
    ) public view {
        FundingRateUtil.calculateBaseRateX96(
            marketConfig.feeRateConfig,
            _longSize,
            _shortSize,
            _premiumRateX96,
            _timeDelta
        );
    }

    function test_settleFundingFee_liquidityIsZero() public {
        state.globalLiquidityPosition.liquidity = 0;
        state.globalPosition.longSize = 1e18;
        state.globalPosition.shortSize = 10e18;

        vm.warp(block.timestamp + 120);
        vm.expectEmit();
        emit IMarketPosition.FundingFeeSettled(
            IMarketDescriptor(address(0x1)),
            state.globalPosition.longFundingRateGrowthX96,
            state.globalPosition.shortFundingRateGrowthX96
        );
        FundingRateUtil.settleFundingFee(
            state,
            marketConfig,
            IPriceFeed(address(priceFeed)),
            IMarketDescriptor(address(0x1))
        );
        assertEq(state.globalPosition.lastFundingFeeSettleTime, block.timestamp);
    }

    function test_settleFundingFee_sizeIsZero() public {
        state.globalPosition.longSize = 0;
        state.globalPosition.shortSize = 0;

        vm.warp(block.timestamp + 120);
        vm.expectEmit();
        emit IMarketPosition.FundingFeeSettled(
            IMarketDescriptor(address(0x1)),
            state.globalPosition.longFundingRateGrowthX96,
            state.globalPosition.shortFundingRateGrowthX96
        );
        FundingRateUtil.settleFundingFee(
            state,
            marketConfig,
            IPriceFeed(address(priceFeed)),
            IMarketDescriptor(address(0x1))
        );
        assertEq(state.globalPosition.lastFundingFeeSettleTime, block.timestamp);
    }

    function test_settleFundingFee_settleTimeIsEqual() public {
        FundingRateUtil.settleFundingFee(
            state,
            marketConfig,
            IPriceFeed(address(priceFeed)),
            IMarketDescriptor(address(0x1))
        );
        assertEq(state.globalPosition.lastFundingFeeSettleTime, block.timestamp);
    }

    function test_settleFundingFee_longSizeGreaterThenShortSize() public {
        vm.warp(block.timestamp + 120);

        state.globalPosition.longSize = 1000000e18;
        state.globalPosition.shortSize = 200000e18;
        state.priceState.premiumRateX96 = 7922816251426433759354395033;
        state.priceState.basisIndexPriceX96 = 2147598187192905;
        priceFeed.setMaxPriceX96(2147598187192905);
        vm.expectEmit();
        emit IMarketManager.ProtocolFeeIncreased(IMarketDescriptor(address(0x1)), 7229);
        vm.expectEmit();
        emit IMarketLiquidityPosition.GlobalLiquidityPositionPnLGrowthIncreasedByFundingFee(
            IMarketDescriptor(address(0x1)),
            16597553903389
        );
        vm.expectEmit();
        emit IMarketPosition.FundingFeeSettled(IMarketDescriptor(address(0x1)), -891432342946, 890000452366);
        FundingRateUtil.settleFundingFee(
            state,
            marketConfig,
            IPriceFeed(address(priceFeed)),
            IMarketDescriptor(address(0x1))
        );
    }

    function test_settleFundingFee_longSizeLessThenShortSize() public {
        vm.warp(block.timestamp + 120);

        state.globalPosition.longSize = 1000000e18;
        state.globalPosition.shortSize = 2000000e18;
        state.priceState.premiumRateX96 = 7922816251426433759354395033;
        state.priceState.basisIndexPriceX96 = 2147598187192905;
        priceFeed.setMaxPriceX96(2147598187192905);
        vm.expectEmit();
        emit IMarketManager.ProtocolFeeIncreased(IMarketDescriptor(address(0x1)), 11295);
        vm.expectEmit();
        emit IMarketLiquidityPosition.GlobalLiquidityPositionPnLGrowthIncreasedByFundingFee(
            IMarketDescriptor(address(0x1)),
            20751107654048
        );
        vm.expectEmit();
        emit IMarketPosition.FundingFeeSettled(IMarketDescriptor(address(0x1)), 889284625917, -890716397655);
        FundingRateUtil.settleFundingFee(
            state,
            marketConfig,
            IPriceFeed(address(priceFeed)),
            IMarketDescriptor(address(0x1))
        );
    }
}
