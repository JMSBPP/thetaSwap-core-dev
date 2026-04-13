// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {IRateProvider}
    from "balancer-v3-monorepo/pkg/interfaces/contracts/solidity-utils/helpers/IRateProvider.sol";
import {IAngstromAccumulatorConsumer}
    from "core/src/interfaces/IAngstromAccumulatorConsumer.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {FullMath} from "v4-core/src/libraries/FullMath.sol";

import {GrowthObservation} from "core/src/types/GrowthObservation.sol";
import {growthToSqrtPriceX96} from "core/src/libraries/GrowthToTickLib.sol";
import {RayMathLib} from "core/src/libraries/RayMathLib.sol";
import "core/src/modules/GrowthObservationStorageMod.sol" as GrowthObservationStorage;

contract VanillaGrowthAccumulatorRateProvider is IRateProvider {
    uint256 constant BUFFER_CAPACITY = 256;
    uint256 constant Q96 = 1 << 96;

    IAngstromAccumulatorConsumer public immutable CONSUMER;
    PoolId public immutable POOL_ID;

    constructor(IAngstromAccumulatorConsumer _consumer, PoolId _poolId) {
        CONSUMER = _consumer;
        POOL_ID = _poolId;
        GrowthObservationStorage.initializePool(_poolId, BUFFER_CAPACITY);
    }

    function recordObservation(uint256 relativeTimeDelta) external {
        uint256 cumulativeGrowth = CONSUMER.globalGrowth(POOL_ID);
        GrowthObservationStorage.recordObservation(
            POOL_ID, block.number, relativeTimeDelta, cumulativeGrowth
        );
    }

    /// @inheritdoc IRateProvider
    function getRate() external view returns (uint256 rate) {
        uint256 count = GrowthObservationStorage.observationCount(POOL_ID);
        if (count < 2) return RayMathLib.RAY;

        GrowthObservation oldest = GrowthObservationStorage.oldestObservation(POOL_ID);
        GrowthObservation latest = GrowthObservationStorage.latestObservation(POOL_ID);

        if (oldest.cumulativeGrowth() == 0) return RayMathLib.RAY;

        uint160 sqrtPriceX96 =
            growthToSqrtPriceX96(latest.cumulativeGrowth(), oldest.cumulativeGrowth());

        rate = FullMath.mulDiv(uint256(sqrtPriceX96), RayMathLib.RAY, Q96);
    }
}
