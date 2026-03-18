---
phase: 3
slug: cli-wiring
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | cargo test (Rust built-in) |
| **Config file** | `d2p/Cargo.toml` |
| **Quick run command** | `cd d2p && cargo check` |
| **Full suite command** | `cd d2p && cargo test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd d2p && cargo check`
- **After every plan wave:** Run `cd d2p && cargo test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | CMD-01..09 | build+unit | `cd d2p && cargo test cli 2>&1` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | OUT-02,OUT-03 | build+unit | `cd d2p && cargo test 2>&1` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `d2p/` crate from Phase 1+2 compiles with 20 tests passing

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full deploy via CLI | CMD-01 | Requires live Foundry + RPC | `d2p ts reactive uniswap-v3 --rpc-url <url> --private-key <key> --callback <addr>` |
| --help output quality | CMD-07 | Visual inspection | `d2p ts reactive --help` — check examples present |
| --version output | CMD-08 | Visual inspection | `d2p --version` — check matches Cargo.toml |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
