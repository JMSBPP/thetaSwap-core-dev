# Range Accrual Note V1a — Core Primitive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the protocol-agnostic ERC-1155 theta token with Angstrom adapter and fork-test validation against paper equations.

**Architecture:** Three contracts compose the core: `IAccumulatorSource` (interface), `AngstromAccumulatorSource` (read-only adapter over Angstrom's GrowthOutsideUpdater storage via `extsload`), and `RangeAccrualNote` (ERC-1155 token with epoch-batched fungibility and basic claim). All Solidity code uses free functions + file-level structs per project convention. No `library` keyword.

**Tech Stack:** Solidity ^0.8.26, Forge (test + fork), Panoptic's LeftRight.sol + ERC1155Minimal.sol (from `~/apps/liq-soldk-dev/lib/2025-12-panoptic/`), Python FFI for differential tests.

**Design Spec:** `docs/superpowers/specs/2026-04-06-range-accrual-note-vanilla-design.md`

**Scope:** V1a only (core primitive). V1b (CollateralManager, SFPM premium streaming, V3 adapter) is a separate plan.

**V1a Limitation:** Mint is ungated (no collateral requirement). This is a simulation testbed for validating the accumulator math and paper equations. Production collateral gating ships in V1b.

**Solidity Review Rule:** All .sol code must be presented piece-by-piece for user approval before writing. Subagents propose; controller presents.

---

## File Structure

```
src/range-accrual-note/
├── interfaces/
│   └── IAccumulatorSource.sol          # Standard accumulator interface (4 functions)
├── types/
│   ├── NoteId.sol                      # tokenId computation + NoteIdComponents struct
│   └── NoteSnapshot.sol                # Per-tokenId storage struct
├── adapters/
│   └── AngstromAccumulatorSource.sol   # Read-only adapter over Angstrom storage via extsload
├── RangeAccrualNote.sol                # ERC-1155 token with mint/claim/accruedTheta

test/range-accrual-note/
├── unit/
│   ├── NoteId.t.sol                    # tokenId computation + determinism + fuzz roundtrip
│   ├── AngstromAccumulatorSource.t.sol # All 3 tick branches via vm.store, epoch math
│   └── RangeAccrualNote.t.sol          # Token lifecycle: mint, claim, transfer
├── fork/
│   ├── AngstromAccumulatorSource.fork.t.sol  # Read real Angstrom mainnet state via extsload
│   └── RangeAccrualNote.differential.t.sol   # FFI to Python paper equations
├── invariant/
│   └── RangeAccrualNote.invariant.t.sol      # Stateful: conservation, monotonicity, supply, transfer neutrality
└── trees/
    ├── AngstromAccumulatorSource_growthInside.tree
    ├── RangeAccrualNote_mint.tree
    ├── RangeAccrualNote_claim.tree
    └── RangeAccrualNote_transfer.tree

research/scripts/
└── ran_oracle.py                       # Python oracle for differential tests
```

---

## Prerequisites

### P1: Resolve Panoptic Dependency

Before any task begins, the Panoptic code must be importable.

- [ ] **Step 1:** Add Foundry remapping for Panoptic's contracts in `foundry.toml`. The source is at `~/apps/liq-soldk-dev/lib/2025-12-panoptic/contracts/`. Alternatively, vendor the needed files (`tokens/ERC1155Minimal.sol`, `types/LeftRight.sol`) into `src/range-accrual-note/vendor/`.
- [ ] **Step 2:** Verify compilation with a trivial import test.
- [ ] **Step 3:** Commit.

**Decision for user:** Vendor copy vs. remapping vs. submodule. Per `feedback_no_modify_lib_submodules.md`, adding a submodule needs explicit approval.

---

## Task 1: IAccumulatorSource Interface

**Files:** Create `src/range-accrual-note/interfaces/IAccumulatorSource.sol`

**Requirements:**
- 4 view functions: `growthInside(bytes32, int24, int24)`, `globalGrowth(bytes32)`, `epochOf(uint256)`, `epochLength()`
- Return types: `int256` for growth functions (LeftRight-packed: left = token0, right = token1)
- `epochOf` takes `uint256 timestamp` (NOT block number — matches FCI V2 convention)
- `epochLength` returns seconds
- NatSpec must document: the three-branch tick logic requirement (below/in/above range), the LeftRight packing convention, and that single-token accumulators use left-only with zero right

- [ ] **Step 1:** Write the interface per spec Section 5
- [ ] **Step 2:** Verify compilation: `forge build --match-path "src/range-accrual-note/**"`
- [ ] **Step 3:** Commit

---

## Task 2: NoteId Type

**Files:** Create `src/range-accrual-note/types/NoteId.sol`, Create `test/range-accrual-note/unit/NoteId.t.sol`

**Requirements:**
- `NoteId` is a user-defined value type wrapping `uint256`
- `computeNoteId(address source, bytes32 poolId, int24 tickLower, int24 tickUpper, uint40 epochId)` returns `NoteId` as `keccak256(abi.encode(...))`. Reverts with `InvalidRange` if `tickLower >= tickUpper`.
- Since keccak is one-way, provide a `NoteIdComponents` struct for storage-backed lookup. The `RangeAccrualNote` contract stores components alongside the hash.
- Global `==` operator via `using ... for NoteId global`

**BTT tree:** Write `test/range-accrual-note/trees/NoteId_encode.tree`

**Tests must cover:**
- Deterministic: same inputs → same NoteId
- Different epochs with same range → different NoteIds
- Revert on `tickLower >= tickUpper`
- Fuzz: `computeNoteId` with arbitrary valid inputs produces non-zero hash

- [ ] **Step 1:** Write BTT tree
- [ ] **Step 2:** Write failing tests
- [ ] **Step 3:** Run tests, confirm compilation fails
- [ ] **Step 4:** Write implementation
- [ ] **Step 5:** Run tests, confirm all pass
- [ ] **Step 6:** Commit

---

## Task 3: NoteSnapshot Type

**Files:** Create `src/range-accrual-note/types/NoteSnapshot.sol`

**Requirements:**
- Struct with fields: `int256 entryGrowthInside` (LeftRight), `int256 entryGlobalGrowth` (LeftRight), `uint128 totalLiquidity`, `uint40 epochId`, `bool initialized`
- Pure data struct, no logic

- [ ] **Step 1:** Write the struct
- [ ] **Step 2:** Verify compilation
- [ ] **Step 3:** Commit

---

## Task 4: AngstromAccumulatorSource — BTT Spec + Unit Tests

**Files:** Create `test/range-accrual-note/trees/AngstromAccumulatorSource_growthInside.tree`, Create `test/range-accrual-note/unit/AngstromAccumulatorSource.t.sol`

**Requirements:**

**BTT tree must cover:**
- `growthInside`: all three tick branches (below, in-range, above) + zero-growth case
- `globalGrowth`: non-zero pool + zero pool
- `epochOf`: correct division by epoch length, boundary values
- `epochLength`: returns configured value

**Unit tests must use `vm.store()` to mock Angstrom storage slots** for the three growthInside branches. Do NOT defer growthInside testing to fork tests only. The slot computation formulas from Exercise B (spec Section 5) define exactly which slots to write:
- `struct_base = keccak256(abi.encode(poolId, 7))`
- `rewardGrowthOutside[tick] = struct_base + uint24(tick)`
- `globalGrowth = struct_base + 16777216`

Test the conservation property: `growthInside + outsideBelow + outsideAbove == globalGrowth` (for the in-range case).

- [ ] **Step 1:** Write BTT tree
- [ ] **Step 2:** Write failing unit tests with `vm.store()` for all three tick branches
- [ ] **Step 3:** Run tests, confirm compilation fails
- [ ] **Step 4:** Commit tests

---

## Task 5: AngstromAccumulatorSource — Implementation

**Files:** Create `src/range-accrual-note/adapters/AngstromAccumulatorSource.sol`

**Requirements:**

**Critical: Use `extsload` for ALL storage reads.** Angstrom exposes `extsload(uint256 slot) external view returns (uint256)` at `Angstrom.sol:86`. V4 PoolManager also exposes `IExtsload.extsload`. The adapter MUST use `staticcall` to these `extsload` functions — NOT raw `sload` (which would read the adapter's own storage).

**Pattern reference:** `~/apps/liq-soldk-dev/lib/angstrom/contracts/src/periphery/AngstromView.sol` demonstrates exactly this pattern: `self.extsload(slot)` for reading Angstrom storage externally. Also reference `IUniV4.gudExtsload()` for the PoolManager read pattern.

**Storage slot computation** (from Exercise B, verified on mainnet):
- `struct_base = keccak256(abi.encode(poolId, 7))` — slot 7 = poolRewards mapping
- `rewardGrowthOutside[tick] = struct_base + uint24(tick)`
- `globalGrowth = struct_base + 16777216` (2^24 offset)

**Three-branch growthInside logic:**
- `current_tick < tickLower`: `outsideBelow - outsideAbove`
- `current_tick in [tickLower, tickUpper)`: `globalGrowth - outsideBelow - outsideAbove`
- `current_tick >= tickUpper`: `outsideAbove - outsideBelow`

**Current tick:** Read from V4 PoolManager via `extsload` on the pool's slot0, using `StateLibrary.getSlot0()` pattern from existing `NativeUniswapV4Facet.sol`.

**LeftRight packing:** Angstrom distributes `bid_in_asset0` only → left half = reward growth, right half = 0.

**Constructor parameters:** `angstromHook` address, `poolManager` address, `epochLengthSeconds`.

- [ ] **Step 1:** Present implementation piece-by-piece for user approval
- [ ] **Step 2:** Run Task 4's unit tests, confirm all pass
- [ ] **Step 3:** Commit

---

## Task 6: Angstrom Fork Tests — Verify Against Mainnet

**Files:** Create `test/range-accrual-note/fork/AngstromAccumulatorSource.fork.t.sol`

**Requirements:**

**Fork test reads real Angstrom mainnet state** to validate:
1. `globalGrowth` is non-zero (rewards have been accumulating since July 2025)
2. Conservation: `growthInside + outsideBelow + outsideAbove == globalGrowth` for in-range tick selection
3. The adapter's `extsload`-based reads match direct `vm.load()` reads (cross-validation)

**Test parameters:**
- Angstrom hook: `0x0000000aa232009084bd71a5797d089aa4edfad4`
- V4 PoolManager: `0x000000000004444c5dc75cB358380D2e3dE08A90`
- Pool ID: `0xe500210c7ea6bfd9f69dce044b09ef384ec2b34832f132baec3b418208e3a657`
- Tick spacing: 10

**Run command:** `ETH_RPC_URL=<rpc> forge test --match-contract AngstromAccumulatorSourceForkTest -vv`

- [ ] **Step 1:** Write fork test
- [ ] **Step 2:** Run against mainnet fork, confirm PASS
- [ ] **Step 3:** Commit

---

## Task 7: RangeAccrualNote — BTT Specs + Failing Tests

**Files:** Create trees + `test/range-accrual-note/unit/RangeAccrualNote.t.sol`

**Requirements:**

**Write BTT trees for three functions:**

`RangeAccrualNote_mint.tree`:
- Valid params: snapshots entryGrowthInside, snapshots entryGlobalGrowth, mints ERC-1155, increments totalLiquidity, stores NoteIdComponents
- Same tokenId (second mint): does NOT re-snapshot, increments totalLiquidity additively
- Invalid range (tickLower >= tickUpper): reverts
- Zero liquidity: reverts

`RangeAccrualNote_claim.tree`:
- Holder with balance + growthInside increased: returns accumulated delta proportional to share
- Holder with balance + growthInside unchanged: returns zero
- Consecutive claims: second returns zero (idempotency)
- Zero balance caller: reverts
- Uninitialized tokenId: reverts

`RangeAccrualNote_transfer.tree`:
- Transfer between holders: balances update correctly
- Transfer does not change total accrued value (transfer neutrality invariant)
- Transfer to self: no-op
- Transfer more than balance: reverts

**Tests use a `MockAccumulatorSource`** that returns configurable `growthInside`/`globalGrowth` values.

**Contract skeleton that tests compile against** (the implementation comes in Task 8):
- `RangeAccrualNote` inherits from Panoptic's `ERC1155Minimal`
- Storage: `mapping(NoteId => NoteSnapshot) public snapshots`, `mapping(NoteId => NoteIdComponents) public components`, `mapping(uint256 => mapping(address => int256)) internal s_lastGrowthInside` (for claim idempotency)
- Functions: `mint(address source, bytes32 poolId, int24 tickLower, int24 tickUpper, uint128 liquidityUnits, address recipient)`, `claim(NoteId id) returns (int256)`, `accruedTheta(NoteId id) view returns (int256)`

- [ ] **Step 1:** Write all three BTT trees
- [ ] **Step 2:** Write MockAccumulatorSource
- [ ] **Step 3:** Write failing tests covering ALL BTT tree leaves
- [ ] **Step 4:** Run tests, confirm compilation fails
- [ ] **Step 5:** Commit

---

## Task 8: RangeAccrualNote — Implementation

**Files:** Create `src/range-accrual-note/RangeAccrualNote.sol`

**Requirements:**

**Inherits from** Panoptic's `ERC1155Minimal`. Uses `LeftRight.sol` for two-token arithmetic.

**`mint` must:**
1. Validate range (`tickLower < tickUpper`) and liquidity (non-zero)
2. Compute `NoteId` via `computeNoteId`
3. If `!snapshots[id].initialized`: read `growthInside` and `globalGrowth` from the `IAccumulatorSource` at `source`, store in snapshot, set `initialized = true`
4. If already initialized: skip re-snapshot
5. Increment `snapshots[id].totalLiquidity`
6. Store `NoteIdComponents` for lookup
7. Mint ERC-1155 tokens: `_mint(recipient, NoteId.unwrap(id), liquidityUnits, "")`

**`claim` must:**
1. Require `balanceOf(msg.sender, NoteId.unwrap(id)) > 0`
2. Require `snapshots[id].initialized`
3. Read current `growthInside` from the accumulator source (stored in components)
4. Compute delta: `currentGrowthInside - s_lastGrowthInside[tokenId][msg.sender]`
5. If delta is zero, return 0
6. Update `s_lastGrowthInside[tokenId][msg.sender] = currentGrowthInside`
7. Scale delta by holder's share: `delta * balanceOf(msg.sender, tokenId) / totalLiquidity`
8. Return the scaled delta (actual token transfer deferred to V1b with CollateralManager)

**`accruedTheta` (view) must:**
1. Read current `growthInside` from accumulator source
2. Return `currentGrowthInside - entryGrowthInside` (total accrual for the tokenId, not per-holder)

**Present each function to user individually for approval before writing.**

- [ ] **Step 1:** Present storage layout + constructor for approval
- [ ] **Step 2:** Present `mint` function for approval
- [ ] **Step 3:** Present `claim` function for approval
- [ ] **Step 4:** Present `accruedTheta` view for approval
- [ ] **Step 5:** Run Task 7's tests, confirm all pass
- [ ] **Step 6:** Commit

---

## Task 9: Invariant Tests

**Files:** Create `test/range-accrual-note/invariant/RangeAccrualNote.invariant.t.sol`

**Requirements:**

**Handler contract** wraps `RangeAccrualNote` + `MockAccumulatorSource` with bounded actions:
- `mint(uint8 actorSeed, int24 tickLower, int24 tickUpper, uint128 liquidity)` — bounded params
- `claim(uint8 actorSeed, uint8 tokenIdSeed)` — picks from known tokenIds
- `transfer(uint8 fromSeed, uint8 toSeed, uint8 tokenIdSeed, uint128 amount)` — bounded
- `advanceGrowth(int256 delta)` — increases mock growthInside (never decreases, for monotonicity)

**Ghost variables** in handler (test-only accumulators):
- `ghost_totalClaimed` per tokenId
- `ghost_totalMinted` per tokenId
- `ghost_previousAccruedTheta` per tokenId (for monotonicity check)

**Invariants to verify (maps to spec Section 9):**

1. **Conservation (1a):** `ghost_totalClaimed[id] <= (currentGrowthInside - entryGrowthInside) * totalLiquidity` for all active tokenIds
2. **Monotonicity (3):** `accruedTheta(id) >= ghost_previousAccruedTheta[id]` after every action where growthInside didn't decrease
3. **Epoch isolation (4):** Claiming on tokenId_A does not change `accruedTheta(tokenId_B)` for B ≠ A
4. **Supply conservation (6):** `note.totalSupply(tokenId) == Σ note.balanceOf(actor, tokenId)` across all tracked actors
5. **Transfer neutrality (5):** Before/after any transfer, `Σ premiumOwed(holder)` over all holders of a tokenId is unchanged

**Run:** `forge test --match-contract RangeAccrualNoteInvariantTest -vv` with `runs = 256, depth = 64`

- [ ] **Step 1:** Write handler contract with ghost variables
- [ ] **Step 2:** Write invariant test contract with all 5 invariant assertions
- [ ] **Step 3:** Run, confirm all invariants hold
- [ ] **Step 4:** Commit

---

## Task 10: Differential Fork Tests — Paper Equations

**Files:** Create `research/scripts/ran_oracle.py`, Create `test/range-accrual-note/fork/RangeAccrualNote.differential.t.sol`

**Requirements:**

**Python oracle** implements three models:
1. **Panoptic convergence:** `dFee/dt = σ²·S²·L / (2·width)` — expected fee rate per unit time
2. **Bichuch-Feinstein:** `implied_fee_rate = LVR / L` — break-even fee from "Price of Liquidity"
3. **Range accrual ratio:** `n/N` — Pap (2022) Eq. 2.1, fraction of observations in range

CLI interface for Forge FFI: takes model name + parameters, outputs X128 fixed-point integer.

**Differential fork test:**
1. Fork mainnet at a specific block
2. Read Angstrom accumulator state via the adapter's `extsload`-based reads
3. Compute the RAN's accumulator delta (Solidity)
4. Call Python oracle via FFI with the same parameters
5. Assert `|contract_value - paper_value| < epsilon` (tolerance calibrated per model)

**Extends existing pattern:** `test/**/FeeConcentrationIndex.fork.t.sol` + `research/scripts/hhi_oracle.py`

**Run:** `ETH_RPC_URL=<rpc> forge test --match-contract RangeAccrualNoteDifferentialTest -vv --ffi`

- [ ] **Step 1:** Write Python oracle with all three models + CLI
- [ ] **Step 2:** Write Solidity differential fork test
- [ ] **Step 3:** Run, confirm PASS within epsilon
- [ ] **Step 4:** Commit

---

## Spec Coverage Checklist

| Spec Section | Task(s) | Status |
|---|---|---|
| 1. Product Definition | Context in spec | N/A |
| 2. Architecture (three-layer) | Tasks 1, 4-6, 7-8 | Covered |
| 3. Token Design (ERC-1155 hybrid, LeftRight) | Tasks 2-3, 7-8 | Covered |
| 3. Fee Growth Scalar Convention | Task 1 (interface NatSpec), Task 5 (left-packing) | Covered |
| 3. Premium variable mapping | Deferred to V1b | Correctly scoped |
| 4. Time Model (range-as-maturity, epoch timestamps) | Tasks 4-5 (epochOf), Task 7-8 (epoch in NoteId) | Covered |
| 5. IAccumulatorSource (3-branch, timestamp, extsload) | Tasks 1, 4-6 | Covered |
| 5. Angstrom storage layout | Tasks 4-6 | Covered |
| 6. Collateral Model | Deferred to V1b | Correctly scoped |
| 7. Panoptic code reuse | Prerequisite P1 | Covered |
| 8. Differential testing | Task 10 | Covered |
| 9. Invariants (1a-c, 2-6) | Task 9 (1a, 3, 4, 5, 6); Inv 2 deferred to V1b | Covered |
| 10. EVM TDD (BTT trees, phases) | Tasks 2, 4, 7 | Covered |
| 11. V1a scope | All tasks | Covered |
| 11. Accumulation Standard (read-only extsload) | Task 5 | Covered |
