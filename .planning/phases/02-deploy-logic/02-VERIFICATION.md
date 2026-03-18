---
phase: 02-deploy-logic
verified: 2026-03-18T01:30:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
---

# Phase 2: Deploy Logic Verification Report

**Phase Goal:** Working `Runner::deploy()` that tries `forge create`, falls back to `cast send --create`, verifies receipt status, and returns a pipe-friendly output or a typed error — before any CLI argument parsing exists
**Verified:** 2026-03-18T01:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (derived from ROADMAP.md Success Criteria + PLAN must_haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `forge create` is invoked with `--constructor-args` last, `--legacy`, `--broadcast`, `--value`, `--json`, and `--rpc-url`; ETH_RPC_URL removed from subprocess env | VERIFIED | `primary.rs:74-90` build_args vec; `primary.rs:41` env_remove; 5 unit tests pass |
| 2 | `cast send --create` places all flags before `--create`, has no `--legacy`, reads bytecode from artifact; ETH_RPC_URL removed from subprocess env | VERIFIED | `fallback.rs:124-140` build_args vec; `fallback.rs:54` env_remove; 5 unit tests pass |
| 3 | `verify::verify()` accepts only `"0x1"` as success and explicitly rejects `"1 (success)"` | VERIFIED | `verify.rs:18` `Some("0x1") => Ok(())`; 4 unit tests pass including `test_verify_rejects_human_string` |
| 4 | `Runner::deploy()` calls `check_prerequisites()` before any other operation | VERIFIED | `mod.rs:73` `check_prerequisites()?;` is first statement in `deploy()` |
| 5 | `Runner::deploy()` falls back to `fallback::run()` with stderr warning when `primary::run()` returns Err | VERIFIED | `mod.rs:74-79` match arm with `eprintln!("[warn] forge create failed ({e}), retrying with cast send --create")` |
| 6 | `Runner::deploy()` calls `verify::verify()` after primary or fallback succeeds | VERIFIED | `mod.rs:81` `verify::verify(&out.tx_hash, &self.params.rpc_url)?;` |
| 7 | `DeployOutput::fmt` writes only `address\ntx_hash` to stdout with no trailing newline | VERIFIED | `mod.rs:25-30` `writeln!(address)` + `write!(tx_hash)`; `test_deploy_output_display_no_newline_suffix` asserts exact string `"0xA\n0xB"` |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `d2p/src/deploy/primary.rs` | forge create invocation + JSON parsing | VERIFIED | Exists, 174 lines, `pub fn run()` exported, `build_args()` private, `ForgeCreateJson` serde struct, 5 inline tests |
| `d2p/src/deploy/fallback.rs` | cast send --create invocation + bytecode reading + JSON parsing | VERIFIED | Exists, 275 lines, `pub fn run()` exported, `read_bytecode()` + `build_args()` private, `CastSendJson` serde struct, 5 inline tests |
| `d2p/src/deploy/verify.rs` | cast receipt --json status check | VERIFIED | Exists, 97 lines, `pub fn verify()` exported, `parse_receipt_status()` private testable helper, 4 inline tests |
| `d2p/src/deploy/mod.rs` | Runner struct + deploy() orchestration + check_prerequisites() | VERIFIED | Exists, 179 lines, `pub struct Runner`, `pub fn new()`, `pub fn deploy()`, `pub fn check_prerequisites()`, 5 inline tests |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `mod.rs Runner::deploy()` | `primary::run()` | `match primary::run(&self.params)` | WIRED | `mod.rs:74` — pattern `primary::run` present |
| `mod.rs Runner::deploy()` | `fallback::run()` | `fallback::run(&self.params)?` in Err arm | WIRED | `mod.rs:78` — called on primary failure |
| `mod.rs Runner::deploy()` | `verify::verify()` | `verify::verify(&out.tx_hash, &self.params.rpc_url)?` | WIRED | `mod.rs:81` — called after both primary and fallback paths |
| `primary.rs run()` | forge subprocess | `Command::new("forge").args(&args).env_remove("ETH_RPC_URL")` | WIRED | `primary.rs:37-41` — env isolation confirmed |
| `fallback.rs run()` | cast subprocess | `Command::new("cast").args(&args).env_remove("ETH_RPC_URL")` | WIRED | `fallback.rs:50-54` — env isolation confirmed |
| `verify.rs verify()` | cast receipt subprocess | `Command::new("cast").args(["receipt", "--rpc-url", rpc_url, tx_hash, "--json"])` | WIRED | `verify.rs:35-37` — "receipt" is first arg |
| `mod.rs check_prerequisites()` | forge/cast PATH check | `Command::new(tool).arg("--version").output()` in loop | WIRED | `mod.rs:39-47` — NotFound mapped to getfoundry.sh error |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DEP-01 | 02-01 | Primary path runs `forge create` with `--broadcast`, `--legacy`, `--value`, `--rpc-url`, `--private-key` | SATISFIED | `primary.rs:74-90` build_args vec; `test_forge_args_contains_legacy` + `test_forge_args_contains_broadcast` pass |
| DEP-02 | 02-01 | Fallback runs `cast send --create` when forge create fails | SATISFIED | `mod.rs:77-78` Err arm; `fallback.rs:123-140` build_args; `test_cast_args_order` verifies flags-before-subcommand |
| DEP-03 | 02-01 | `--legacy` only on forge create path, not cast send fallback | SATISFIED | `fallback.rs` build_args has no `--legacy`; `test_cast_args_no_legacy` passes |
| DEP-04 | 02-02 | forge and cast checked on PATH before deployment; fails with "Install Foundry: https://getfoundry.sh" | SATISFIED | `mod.rs:37-49` check_prerequisites(); error message `mod.rs:43` contains exact URL; tests `test_check_prerequisites_missing_tool` + `test_check_prerequisites_bad_name` pass |
| DEP-05 | 02-02 | `cast receipt <txhash> --field status` called after deployment; verifies `0x1` | SATISFIED | `verify.rs:34-46`; `mod.rs:81`; `test_verify_rejects_human_string` confirms only hex "0x1" accepted |
| DEP-06 | 02-01 | `--constructor-args` placed last in forge create command | SATISFIED | `primary.rs:87-88` last two pushes; `test_forge_args_order` asserts `args[len-2] == "--constructor-args"` |
| OUT-01 | 02-02 | Stdout prints deployed address and tx hash on success | SATISFIED | `mod.rs:25-30` Display impl; `test_deploy_output_display` verifies exact format |
| OUT-04 | 02-02 | No diagnostic noise on stdout; all warnings go to stderr | SATISFIED | Fallback warning uses `eprintln!` (`mod.rs:77`); `DeployOutput::fmt` emits only address + tx_hash |

**All 8 requirements satisfied. No orphaned requirements.**

Orphaned check: REQUIREMENTS.md Traceability table maps DEP-01 through DEP-06, OUT-01, OUT-04 to Phase 2. All 8 IDs appear in plan frontmatter (`02-01`: DEP-01, DEP-02, DEP-03, DEP-06; `02-02`: DEP-04, DEP-05, OUT-01, OUT-04). No REQUIREMENTS.md Phase 2 entries are absent from plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `d2p/src/main.rs` | 1-6 | `fn main() -> anyhow::Result<()> { Ok(()) }` — empty entry point | Info | Expected: Phase 3 (CLI Wiring) will populate main(). Deploy logic is complete as a library layer. No impact on phase goal. |
| All deploy modules | - | 6 compiler warnings: `check_prerequisites`, `Runner`, `run`, `verify` never used from main | Info | Expected: Phase 3 wires main() to Runner. Dead code warnings are correct for the current state. Not a phase 2 concern. |
| `mod.rs:122-140` | 122 | `test_check_prerequisites_missing_tool` tests error format by constructing a string rather than calling `check_prerequisites()` directly with a bad tool | Warning | Test validates the message format but does not exercise the actual `check_prerequisites()` code path. `test_check_prerequisites_bad_name` (line 144) covers the same message construction without invoking the real function. Neither test calls `check_prerequisites()` with a mocked bad tool — they simulate the format string. The actual NotFound branch in `check_prerequisites()` is structurally correct but its error propagation is not exercised by a test that calls the function itself. |

The anti-pattern at `test_check_prerequisites_missing_tool` and `test_check_prerequisites_bad_name` is a warning-level concern: both tests validate the error message format by constructing the string manually, not by calling `check_prerequisites()` with a nonexistent tool name. The function's error path is indirectly confirmed correct (identical string construction, same match arm), but a future refactor of `check_prerequisites()` could silently break the error text without either test catching it. This does not block Phase 2 goal achievement since the function implementation is demonstrably correct.

### Human Verification Required

None. All phase 2 goals are verifiable programmatically. Phase 2 explicitly excludes CLI argument parsing, so no end-to-end invocation check is needed at this stage.

### Test Suite Results

Full `cargo test` run (observed directly):

```
running 20 tests
test deploy::fallback::tests::test_cast_args_order ... ok
test deploy::fallback::tests::test_cast_args_no_legacy ... ok
test deploy::fallback::tests::test_parse_cast_json ... ok
test deploy::fallback::tests::test_read_bytecode_missing_artifact ... ok
test deploy::primary::tests::test_forge_args_contains_broadcast ... ok
test deploy::primary::tests::test_forge_args_contains_legacy ... ok
test deploy::fallback::tests::test_read_bytecode_missing_field ... ok
test deploy::primary::tests::test_forge_args_no_env_inheritance ... ok
test deploy::primary::tests::test_forge_args_order ... ok
test deploy::primary::tests::test_parse_forge_json ... ok
test deploy::tests::test_deploy_output_display ... ok
test deploy::tests::test_deploy_output_display_no_newline_suffix ... ok
test deploy::tests::test_deploy_params_debug ... ok
test deploy::verify::tests::test_verify_receipt_missing_status ... ok
test deploy::verify::tests::test_verify_receipt_reverted ... ok
test deploy::tests::test_check_prerequisites_missing_tool ... ok
test deploy::tests::test_check_prerequisites_bad_name ... ok
test deploy::verify::tests::test_verify_receipt_success ... ok
test errors::tests::test_d2p_error_variants ... ok
test deploy::verify::tests::test_verify_rejects_human_string ... ok

test result: ok. 20 passed; 0 failed; 0 ignored; 0 measured
```

`cargo build` exits 0.

### Summary

Phase 2 goal is fully achieved. All four deploy modules exist with substantive implementations. The Runner orchestration wires primary → (optional fallback) → verify exactly as specified. All 8 required requirement IDs (DEP-01 through DEP-06, OUT-01, OUT-04) are satisfied with direct code evidence and passing unit tests. The dead-code compiler warnings are structural — expected because Phase 3 (CLI Wiring) has not yet connected main() to Runner.

---

_Verified: 2026-03-18T01:30:00Z_
_Verifier: Claude (gsd-verifier)_
