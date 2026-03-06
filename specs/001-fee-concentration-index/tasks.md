# Tasks: Fee Concentration Index (v2 — Co-Primary State + Diamond Pattern)

**Input**: Design documents from `specs/001-fee-concentration-index/`
**Prerequisites**: plan.md, spec.md (v2), invariants.md (21 invariants), data-model.md, contracts/
**Tests**: Required — TDD skill mandates Kontrol proofs and fuzz tests before implementation.
**Organization**: Tasks grouped by TDD phase, then by user story within implementation phases. Kontrol proofs ONE AT A TIME per TDD skill.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1–US6)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure. Invariants already defined in `specs/001-fee-concentration-index/invariants.md` (21 invariants: INV-001–010, FCI-001–011).

- [ ] T001 Create directory structure: `src/fee-concentration-index/types/`, `test/fee-concentration-index/kontrol/`, `test/fee-concentration-index/fuzz/`, `test/fee-concentration-index/unit/`
- [ ] T002 Verify invariants document `specs/001-fee-concentration-index/invariants.md` has 21 invariants in Hoare triple format (10 INV + 11 FCI)

**Checkpoint**: Directory structure exists, 21 invariants defined. Ready for type design.

---

## Phase 2: Type Definitions (TDD Phase 3 — BLOCKING)

**Purpose**: Define all UDVTs, structs, and Mod files. Types MUST compile. No business logic.

**CRITICAL**: No user story implementation can begin until all types are defined and reviewed.

### Existing types (already implemented, verify compile)

- [ ] T003 [P] Verify `src/fee-concentration-index/types/BlockCountMod.sol` compiles — `type BlockCount is uint256` with unwrap, isZero, floorOne
- [ ] T004 [P] Verify `src/fee-concentration-index/types/FeeShareRatioMod.sol` compiles — `type FeeShareRatio is uint128` with fromFeeGrowth, fromFeeGrowthDelta, square, unwrap, isZero
- [ ] T005 [P] Verify `src/fee-concentration-index/types/SwapCountMod.sol` compiles — `type SwapCount is uint256` with increment, unwrap, isZero

### New type: FeeConcentrationState (replaces AccumulatedHHIMod.sol)

- [ ] T006 [US5] Create `src/fee-concentration-index/types/FeeConcentrationStateMod.sol` — struct FeeConcentrationState { uint256 accumulatedSum; uint256 thetaSum; uint256 posCount; } with free functions: addTerm, incrementPos, decrementPos, toIndexA, atNull, deltaPlus, toDeltaPlusPrice. `using {...} for FeeConcentrationState global`
- [ ] T007 [US5] Delete `src/fee-concentration-index/types/AccumulatedHHIMod.sol` — replaced by FeeConcentrationStateMod.sol

### Storage type update

- [ ] T008 [US5] Update `src/fee-concentration-index/modules/FeeConcentrationIndexStorageMod.sol` — change `mapping(PoolId => AccumulatedHHI) accumulatedHHI` to `mapping(PoolId => FeeConcentrationState) fciState`

### Interface update

- [ ] T009 [US5] Update `src/fee-concentration-index/interfaces/IFeeConcentrationIndex.sol` — change `getIndex()` return from `(uint128 indexA, uint128 indexB)` to `(uint128 indexA, uint256 thetaSum, uint256 posCount)`

- [ ] T010 Verify all types compile with `forge build --out out2` — no business logic, only type definitions and arithmetic helpers

**Checkpoint**: All types compile. User review gate per TDD skill. Ready for proofs.

---

## Phase 3: Kontrol Proofs — FeeConcentrationState (TDD Phase 4)

**Purpose**: Scaffold formal proofs for co-primary state type. ONE proof at a time: build → prove → review → next.

**Covers invariants**: FCI-001 through FCI-011

- [ ] T011 [US5] Write Kontrol proof `prove_fci_indexBoundedness` in `test/fee-concentration-index/kontrol/FeeConcentrationState.k.sol` — FCI-001: 0 <= toIndexA(state) <= Q128. Build and prove.
- [ ] T012 [US5] Write Kontrol proof `prove_fci_thetaSumNonNeg` — FCI-002: addTerm only increases thetaSum. Build and prove.
- [ ] T013 [US5] Write Kontrol proof `prove_fci_posCountNonNeg` — FCI-003: decrementPos requires posCount > 0. Build and prove.
- [ ] T014 [US5] Write Kontrol proof `prove_fci_deviationNonNeg` — FCI-005: deltaPlus(state) >= 0 for all valid states. Build and prove.
- [ ] T015 [US5] Write Kontrol proof `prove_fci_deviationUpperBound` — FCI-006: deltaPlus(state) < Q128. Build and prove.
- [ ] T016 [US5] Write Kontrol proof `prove_fci_coPrimaryConsistency` — FCI-007: same state produces same deltaPlus. Build and prove.
- [ ] T017 [US5] Write Kontrol proof `prove_fci_priceNonNeg` — FCI-009: toDeltaPlusPrice(state) >= 0. Build and prove.
- [ ] T018 [US5] Write Kontrol proof `prove_fci_priceMonotonicity` — FCI-010: higher deltaPlus → higher price. Build and prove.
- [ ] T019 [US5] Write Kontrol proof `prove_fci_priceInvertibility` — FCI-011: delta = p*Q128/(Q128+p) round-trips. Build and prove.
- [ ] T020 [US3] Write Kontrol proof `prove_accumulatedSum_monotonic` in `test/fee-concentration-index/kontrol/FeeConcentrationState.k.sol` — INV-008: addTerm only increases accumulatedSum. Build and prove.
- [ ] T021 [US3] Write Kontrol proof `prove_indexA_capped_at_one` — INV-009: toIndexA capped at INDEX_ONE. Build and prove.

**Checkpoint**: All 11 FeeConcentrationState proofs pass. Delete old `test/fee-concentration-index/kontrol/AccumulatedHHI.k.sol`.

---

## Phase 4: Kontrol Proofs — Existing Types (TDD Phase 4 continued)

**Purpose**: Proofs for SwapCount, TickRangeRegistry, FeeShareRatio types. ONE at a time.

**Covers invariants**: INV-001 through INV-007, INV-010

- [ ] T022 [US1] Write Kontrol proof `prove_swapCount_increment_monotonic` in `test/fee-concentration-index/kontrol/SwapCount.k.sol` — INV-001. Build and prove.
- [ ] T023 [US1] Write Kontrol proof `prove_swapCount_initial_zero` — INV-002. Build and prove.
- [ ] T024 [US1] Write Kontrol proof `prove_register_adds_position` in `test/fee-concentration-index/kontrol/TickRangeRegistry.k.sol` — INV-004. Build and prove.
- [ ] T025 [US1] Write Kontrol proof `prove_deregister_removes_position` — INV-004. Build and prove.
- [ ] T026 [US1] Write Kontrol proof `prove_deregister_last_deletes_range` — INV-005. Build and prove.
- [ ] T027 [US2] Write Kontrol proof `prove_feeShareRatio_bounds` in `test/fee-concentration-index/kontrol/FeeShareRatio.k.sol` — INV-006. Build and prove.
- [ ] T028 [US2] Write Kontrol proof `prove_feeShareRatio_zero_when_no_global_fees` — INV-007. Build and prove.
- [ ] T029 [US3] Write Kontrol proof `prove_zero_lifetime_skipped` in `test/fee-concentration-index/kontrol/IndexUpdate.k.sol` — INV-010. Build and prove.

**Checkpoint**: All existing-type proofs pass. Proof scaffold complete.

---

## Phase 5: Static Analysis Gate (TDD Phase 5)

**Purpose**: Run static analysis on type scaffold BEFORE any implementation logic.

- [ ] T030 Run Slither on `src/fee-concentration-index/` — zero findings required
- [ ] T031 Run Semgrep smart contract rules on `src/fee-concentration-index/` — zero findings required

**Checkpoint**: Static analysis clean on types. Ready for implementation.

---

## Phase 6: Implementation — US1 Track Position Lifetimes (Priority: P1)

**Goal**: Track per-position swap counts, grouped by tick range for O(1) lookup.

**Depends on**: Phase 2 (types), Phase 3–4 (proofs)

- [ ] T032 [US1] Implement TickRangeRegistryMod free functions in `src/fee-concentration-index/types/TickRangeRegistryMod.sol` — register, deregister, getPositionsInRange, computeRangeKey (FR-001a, FR-002, FR-002b)
- [ ] T033 [US1] Implement afterAddLiquidity logic in hook: derive positionKey, initialize SwapCount to 0, register in TickRangePositionSet, increment posCount (FR-002, FR-013)
- [ ] T034 [US1] Implement afterSwap tick-range walking logic: read tick bitmap via StateLibrary, identify overlapping ranges, increment SwapCount (FR-001, FR-001b)

### Fuzz Tests for US1

- [ ] T035 [P] [US1] Write fuzz test `testFuzz_swapCount_monotonic` in `test/fee-concentration-index/fuzz/PositionLifetime.t.sol`
- [ ] T036 [P] [US1] Write fuzz test `testFuzz_register_deregister_roundtrip` in `test/fee-concentration-index/fuzz/TickRangeRegistry.t.sol`
- [ ] T037 [P] [US1] Write fuzz test `testFuzz_only_active_range_incremented` in `test/fee-concentration-index/fuzz/TickRangeRegistry.t.sol` — INV-003

**Checkpoint**: Position lifetime tracking works. Kontrol proofs + fuzz tests pass.

---

## Phase 7: Implementation — US2 Compute Fee Share Ratio (Priority: P1)

**Goal**: Compute x_k = feeGrowthInside / feeGrowthGlobal as Q128 in [0, 1] at removal.

**Depends on**: Phase 2 (types), Phase 4 (FeeShareRatio proofs)

- [ ] T038 [US2] Implement fee share computation in hook afterRemoveLiquidity: read StateLibrary.getFeeGrowthInside, compute Q128 ratio (FR-005, FR-011)

### Fuzz Tests for US2

- [ ] T039 [P] [US2] Write fuzz test `testFuzz_feeShareRatio_bounds` in `test/fee-concentration-index/fuzz/FeeShareRatio.t.sol` — x_k always <= 2^128
- [ ] T040 [P] [US2] Write fuzz test `testFuzz_feeShareRatio_square_precision` in `test/fee-concentration-index/fuzz/FeeShareRatio.t.sol`

**Checkpoint**: Fee share ratio computation works with Q128 precision. No overflow.

---

## Phase 8: Implementation — US3 Update Fee Concentration Index (Priority: P2)

**Goal**: On removal, compute theta, update accumulatedSum + thetaSum, expose (A_T, thetaSum, posCount).

**Depends on**: US1 (lifetime) and US2 (fee share) complete.

- [ ] T041 [US3] Implement afterRemoveLiquidity index update: compute theta = 1/blockLifetime, x_k^2, call fciState.addTerm(), fciState.decrementPos() (FR-004, FR-006, FR-010, FR-013)
- [ ] T042 [US3] Implement getIndex view function returning (A_T, thetaSum, posCount) per FR-007/FR-012

### Fuzz Tests for US3

- [ ] T043 [P] [US3] Write fuzz test `testFuzz_jit_position_max_concentration` in `test/fee-concentration-index/fuzz/IndexUpdate.t.sol` — JIT (lifetime=1, x_k=1) produces A_T == 1 (SC-001)
- [ ] T044 [P] [US3] Write fuzz test `testFuzz_index_monotonic` — A_T never decreases (INV-008)
- [ ] T045 [P] [US3] Write fuzz test `testFuzz_index_formula_matches_spec` — N equal positions match SC-002 formula

**Checkpoint**: Full index computation works. JIT → A_T = 1. Formula matches spec.

---

## Phase 9: Implementation — US5 Co-Primary State (Priority: P1)

**Goal**: Verify atNull, deltaPlus, price computation from stored triple end-to-end.

**Depends on**: US3 (index update writes thetaSum and posCount).

- [ ] T046 [US5] Write unit test `test_atNull_zero_when_no_positions` in `test/fee-concentration-index/unit/FeeConcentrationState.t.sol` — posCount=0 → atNull=0 (edge case)
- [ ] T047 [US5] Write unit test `test_deltaPlus_equals_AT_when_no_active_positions` — N=0, Theta=0, A_T>0 → Delta+=A_T (edge case)
- [ ] T048 [US5] Write unit test `test_deltaPlus_zero_symmetric_pool` — A_T=0.5, Theta=Q128, N=2 → atNull=0.5, Delta+=0 (acceptance scenario 4)
- [ ] T049 [US5] Write fuzz test `testFuzz_fci_nullLowerBound` — FCI-004: A_T >= atNull when posCount > 0

**Checkpoint**: Co-primary derived quantities correct. All acceptance scenarios from US5 verified.

---

## Phase 10: Implementation — US6 Diamond Pattern Compatibility (Priority: P1)

**Goal**: Remove BaseHook inheritance, make poolManager immutable, remove getHookPermissions.

**Depends on**: US3 (hook logic exists to refactor).

- [ ] T050 [US6] Rewrite `src/fee-concentration-index/FeeConcentrationIndex.sol`: remove `is BaseHook`, make poolManager `immutable` set in constructor, remove `getHookPermissions()`, rename `_afterAddLiquidity` → `afterAddLiquidity` (external), same for all hook functions (FR-014)
- [ ] T051 [US6] Update `test/fee-concentration-index/harness/FeeConcentrationIndexHarness.sol` — remove BaseHook adapter, update for external hook functions
- [ ] T052 [US6] Write unit test `test_facet_callable_via_delegatecall` in `test/fee-concentration-index/unit/DiamondCompatibility.t.sol` — call afterAddLiquidity via delegatecall from test diamond, verify state updates (acceptance scenario 1)
- [ ] T053 [US6] Write unit test `test_poolManager_immutable_survives_delegatecall` — read poolManager via delegatecall, verify correct address (acceptance scenario 2)
- [ ] T054 [US6] Write unit test `test_no_baseHook_no_getHookPermissions` — verify contract does not define getHookPermissions, does not use `is BaseHook` (acceptance scenario 3)

**Checkpoint**: FCI is a standalone diamond facet. All US6 acceptance scenarios pass.

---

## Phase 11: Implementation — US4 EVM Number Representation (Priority: P2)

**Goal**: Verify all fixed-point arithmetic is overflow-free and precision adequate.

**Depends on**: US2 (FeeShareRatio) and US3 (index) types exist.

### Kontrol Proofs for US4

- [ ] T055 [US4] Write Kontrol proof `prove_q128_boundary_squaring` in `test/fee-concentration-index/kontrol/FeeShareRatio.k.sol` — x_k = 2^128 squares without overflow
- [ ] T056 [US4] Write Kontrol proof `prove_q128_division_precision` — feeGrowthInside / feeGrowthGlobal preserves >= 64 bits precision
- [ ] T057 [US4] Write Kontrol proof `prove_sqrt_q128_precision` — sqrt(Q256) produces correct Q128 result

### Fuzz Tests for US4

- [ ] T058 [P] [US4] Write fuzz test `testFuzz_q128_squaring_boundary` in `test/fee-concentration-index/fuzz/FeeShareRatio.t.sol`
- [ ] T059 [P] [US4] Write fuzz test `testFuzz_accumulated_sum_no_overflow` in `test/fee-concentration-index/fuzz/IndexUpdate.t.sol`

**Checkpoint**: All Q128 arithmetic overflow-free. SC-006 satisfied.

---

## Phase 12: Polish & Cross-Cutting Concerns (TDD Phase 7)

**Purpose**: Final verification, gas optimization, static analysis re-run.

- [ ] T060 Run Slither on full `src/fee-concentration-index/` — zero findings
- [ ] T061 Run Semgrep on full `src/fee-concentration-index/` — zero findings
- [ ] T062 Gas benchmark: afterSwap with 10 positions < 50k gas (SC-004)
- [ ] T063 Gas benchmark: afterRemoveLiquidity < 100k gas (SC-005)
- [ ] T064 Verify all 21 invariants covered by at least one Kontrol proof or fuzz test
- [ ] T065 Final `forge test --out out2` — all tests pass
- [ ] T066 Final `kontrol prove` — all formal proofs pass

**Checkpoint**: All tests pass, static analysis clean, gas budgets met, 21 invariants fully covered.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies
- **Phase 2 (Types)**: Depends on Phase 1 — BLOCKS everything
- **Phase 3–4 (Proofs)**: Depends on Phase 2 — proofs scaffold types
- **Phase 5 (Static Analysis)**: Depends on Phase 2 — gate before implementation
- **Phase 6 (US1)**: Depends on Phase 5
- **Phase 7 (US2)**: Depends on Phase 5 — can parallel with US1
- **Phase 8 (US3)**: Depends on US1 AND US2
- **Phase 9 (US5)**: Depends on US3 (needs index update for end-to-end)
- **Phase 10 (US6)**: Depends on US3 (hook logic exists to refactor)
- **Phase 11 (US4)**: Depends on US2 and US3
- **Phase 12 (Polish)**: Depends on all user stories

### Execution Graph

```
Phase 1 → Phase 2 → Phase 3–4 → Phase 5
                                    ├── Phase 6 (US1) ──┐
                                    └── Phase 7 (US2) ──┼── Phase 8 (US3) ──┬── Phase 9 (US5)
                                                        │                   ├── Phase 10 (US6)
                                                        └───────────────────┴── Phase 11 (US4) → Phase 12
```

### Within Each Phase (TDD Order)

1. Kontrol proofs written ONE AT A TIME (build → prove → review → next)
2. Implementation after proof scaffold exists
3. Fuzz tests after implementation
4. User review gate after each file

### Parallel Opportunities

- T003–T005: Existing type verification in parallel
- Phase 6 (US1) and Phase 7 (US2) can run in parallel
- Fuzz tests within a phase marked [P] can run in parallel
- T058–T059: US4 fuzz tests in parallel

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Kontrol proofs are ONE AT A TIME per TDD skill — no batching
- Each file gets user review before moving to next file
- SCOP: No `is`, no `library`, no `modifier` in production code
- Commit after each task or logical group
- FeeConcentrationState replaces AccumulatedHHI throughout
- getIndex returns (A_T, thetaSum, posCount) not (A_T, B_T)
- BaseHook removal in Phase 10 — all prior phases can use existing harness
