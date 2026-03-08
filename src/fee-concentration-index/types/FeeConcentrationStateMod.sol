// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {BlockCount} from "./BlockCountMod.sol";

// Co-primary state for the Fee Concentration Index.
// Replaces bare AccumulatedHHI UDVT with a triple that enables
// computing the competitive null (atNull) and deviation (Delta+).
//
// accumulatedSum   = Σ(θ_k · x_k²), Q128 — cumulative over removals
// thetaSum         = Σ(1/ℓ_k), Q128 — cumulative over removals
// posCount         = active positions (inc on add, dec on remove)
// removedPosCount  = N in eq.(5): positions that contributed to the sum
//                    (inc in addTerm, never decremented). Used by atNull.

struct FeeConcentrationState {
    uint256 accumulatedSum;
    uint256 thetaSum;
    uint256 posCount;
    uint256 removedPosCount;
}

uint256 constant Q128 = 1 << 128;
uint128 constant INDEX_ONE = type(uint128).max;

error FeeConcentrationState__DecrementZero();

// Add a removed-position term: θ_k = 1/ℓ_k, contribution = θ_k · x_k²
// Updates both accumulatedSum and thetaSum atomically (FCI-008).
function addTerm(
    FeeConcentrationState storage self,
    BlockCount blockLifetime,
    uint256 xSquaredQ128
) {
    uint256 lifetime = blockLifetime.floorOne();
    // θ_k · x_k² in Q128: xSquaredQ128 is already Q128, divide by lifetime
    self.accumulatedSum = self.accumulatedSum + (xSquaredQ128 / lifetime);
    // θ_k = Q128 / lifetime (Q128 representation of 1/ℓ_k)
    self.thetaSum = self.thetaSum + (Q128 / lifetime);
    // N for the competitive null: counts positions that contributed terms
    self.removedPosCount = self.removedPosCount + 1;
}

// Increment active position count (called on afterAddLiquidity).
function incrementPos(FeeConcentrationState storage self) {
    self.posCount = self.posCount + 1;
}

// Decrement active position count (called on afterRemoveLiquidity, after addTerm).
// Reverts if posCount is already 0 (FCI-003).
function decrementPos(FeeConcentrationState storage self) {
    if (self.posCount == 0) revert FeeConcentrationState__DecrementZero();
    self.posCount = self.posCount - 1;
}

// A_T = sqrt(accumulatedSum) in Q128, capped at INDEX_ONE.
// FCI-001: 0 <= result <= Q128.
function toIndexA(FeeConcentrationState storage self) view returns (uint128) {
    uint256 raw = self.accumulatedSum;
    if (raw >= Q128) return INDEX_ONE;
    // sqrt(raw << 128) gives Q128 result. Safe: raw < Q128 so (raw << 128) < 2^256
    uint256 a = FixedPointMathLib.sqrt(raw << 128);
    if (a > INDEX_ONE) return INDEX_ONE;
    return uint128(a);
}

// Competitive null: atNull = sqrt(thetaSum / N²) in Q128.
// N = removedPosCount: the number of positions whose terms are in the sum.
// This is Sybil-resistant (inflating N with dust increases Δ⁺, see notes.md).
// When N=0 or thetaSum=0, returns 0.
function atNull(FeeConcentrationState storage self) view returns (uint128) {
    uint256 n = self.removedPosCount;
    uint256 theta = self.thetaSum;
    if (n == 0) return 0;
    if (theta == 0) return 0;
    // thetaSum / N² (Q128 / dimensionless = Q128)
    uint256 ratio = theta / (n * n);
    if (ratio >= Q128) return INDEX_ONE;
    uint256 a = FixedPointMathLib.sqrt(ratio << 128);
    if (a > INDEX_ONE) return INDEX_ONE;
    return uint128(a);
}

// Delta+ = max(0, A_T - atNull) in Q128.
// FCI-005: result >= 0.
// FCI-006: result < Q128 (when posCount >= 1).
function deltaPlus(FeeConcentrationState storage self) view returns (uint128) {
    uint128 a = toIndexA(self);
    uint128 n = atNull(self);
    if (a <= n) return 0;
    return a - n;
}

// Concentration price: p = Delta+ / (Q128 - Delta+).
// FCI-009: result >= 0.
// FCI-010: monotone in Delta+.
// Returns Q128 representation. Reverts if Delta+ >= Q128 (should not happen per FCI-006).
function toDeltaPlusPrice(FeeConcentrationState storage self) view returns (uint256) {
    uint256 d = deltaPlus(self);
    if (d == 0) return 0;
    // p = d * Q128 / (Q128 - d), result in Q128
    return FixedPointMathLib.mulDiv(d, Q128, Q128 - d);
}

using {
    addTerm,
    incrementPos,
    decrementPos,
    toIndexA,
    atNull,
    deltaPlus,
    toDeltaPlusPrice
} for FeeConcentrationState global;
