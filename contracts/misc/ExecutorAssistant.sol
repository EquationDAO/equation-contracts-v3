// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.23;

import "../plugins/PositionRouterUpgradeable.sol";

contract ExecutorAssistant {
    struct IndexPerOperation {
        /// @dev The start index of the operation
        uint128 index;
        /// @dev The next index of the operation
        uint128 indexNext;
        /// @dev The end index of the operation.
        /// If the index == indexNext, indexEnd is invalid.
        uint128 indexEnd;
    }

    PositionRouterUpgradeable public immutable positionRouter;

    constructor(PositionRouterUpgradeable _positionRouter) {
        positionRouter = _positionRouter;
    }

    /// @dev Calculate the next market that `Multicall` needs to update the price, and the required indexEnd
    /// @param _max The maximum index that execute in one call
    /// @return markets The market in which to update the price, address(0) means no operation
    /// @return indexPerOperations The index of the per operation
    function calculateNextMulticall(
        uint128 _max
    ) external view returns (IMarketDescriptor[] memory markets, IndexPerOperation[4] memory indexPerOperations) {
        markets = new IMarketDescriptor[](4 * _max);
        uint256 marketIndex;

        // scope for increase liquidity position
        {
            IndexPerOperation memory indexPerOperation = indexPerOperations[0];
            (indexPerOperation.index, indexPerOperation.indexNext) = (
                positionRouter.increaseLiquidityPositionIndex(),
                positionRouter.increaseLiquidityPositionIndexNext()
            );
            if (indexPerOperation.index != indexPerOperation.indexNext) {
                indexPerOperation.indexEnd = uint128(
                    Math.min(indexPerOperation.index + _max, indexPerOperation.indexNext)
                );
                uint128 index = indexPerOperation.index;
                while (index < indexPerOperation.indexEnd) {
                    (address account, IMarketDescriptor market, , , , , , ) = positionRouter
                        .increaseLiquidityPositionRequests(index);
                    if (account != address(0)) markets[marketIndex++] = market;

                    // prettier-ignore
                    unchecked { index++; }
                }
            }
        }

        // scope for decrease liquidity position
        {
            IndexPerOperation memory indexPerOperation = indexPerOperations[1];
            (indexPerOperation.index, indexPerOperation.indexNext) = (
                positionRouter.decreaseLiquidityPositionIndex(),
                positionRouter.decreaseLiquidityPositionIndexNext()
            );
            if (indexPerOperation.index != indexPerOperation.indexNext) {
                indexPerOperation.indexEnd = uint128(
                    Math.min(indexPerOperation.index + _max, indexPerOperation.indexNext)
                );
                uint128 index = indexPerOperation.index;
                while (index < indexPerOperation.indexEnd) {
                    (address account, IMarketDescriptor market, , , , , , , ) = positionRouter
                        .decreaseLiquidityPositionRequests(index);
                    if (account != address(0)) markets[marketIndex++] = market;

                    // prettier-ignore
                    unchecked { index++; }
                }
            }
        }

        // scope for increase position
        {
            IndexPerOperation memory indexPerOperation = indexPerOperations[2];
            (indexPerOperation.index, indexPerOperation.indexNext) = (
                positionRouter.increasePositionIndex(),
                positionRouter.increasePositionIndexNext()
            );
            if (indexPerOperation.index != indexPerOperation.indexNext) {
                indexPerOperation.indexEnd = uint128(
                    Math.min(indexPerOperation.index + _max, indexPerOperation.indexNext)
                );
                uint128 index = indexPerOperation.index;
                while (index < indexPerOperation.indexEnd) {
                    (address account, IMarketDescriptor market, , , , , , , ) = positionRouter.increasePositionRequests(
                        index
                    );
                    if (account != address(0)) markets[marketIndex++] = market;

                    // prettier-ignore
                    unchecked { index++; }
                }
            }
        }

        // scope for decrease position
        {
            IndexPerOperation memory indexPerOperation = indexPerOperations[3];
            (indexPerOperation.index, indexPerOperation.indexNext) = (
                positionRouter.decreasePositionIndex(),
                positionRouter.decreasePositionIndexNext()
            );
            if (indexPerOperation.index != indexPerOperation.indexNext) {
                indexPerOperation.indexEnd = uint128(
                    Math.min(indexPerOperation.index + _max, indexPerOperation.indexNext)
                );
                uint128 index = indexPerOperation.index;
                while (index < indexPerOperation.indexEnd) {
                    (address account, IMarketDescriptor market, , , , , , , , ) = positionRouter
                        .decreasePositionRequests(index);
                    if (account != address(0)) markets[marketIndex++] = market;

                    // prettier-ignore
                    unchecked { index++; }
                }
            }
        }
        uint256 dropNum = markets.length - marketIndex;
        // prettier-ignore
        assembly { mstore(markets, sub(mload(markets), dropNum)) }
    }
}
