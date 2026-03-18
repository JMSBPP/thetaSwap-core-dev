# EVM-Targeting Programming Languages: Landscape Research

**Date**: 2026-03-15
**Scope**: Languages that compile to EVM bytecode (or closely related compilation targets)

---

## Executive Summary

The EVM language ecosystem in early 2026 consists of two dominant production languages (Solidity, Vyper), a handful of specialized/low-level tools (Huff, Yul, ETK), and a growing cohort of experimental next-generation compilers (Plank, Edge, Fe, solx). The most significant developments since 2024 are:

1. **Plank** (formerly Sensei) -- the project the user specifically asked about -- is in Phase I (MVP, targeting end of Q1 2026) with a language-agnostic IR called Sensei IR (SIR).
2. **solx** by Matter Labs + Nomic Foundation is an LLVM-based Solidity compiler already beating `solc --via-ir --optimize` on gas benchmarks, currently in beta.
3. **Core Solidity / SAIL** is the Solidity team's long-term rewrite introducing an algebraic IR, generics, and algebraic data types -- effectively a new language inside Solidity's skin.
4. **Vyper 0.4.x** continues steady releases with the Venom optimizer pipeline yielding ~5% smaller bytecode per release.
5. Most "academic" EVM languages (Flint, Bamboo, Obsidian, Lira, Elle) are dormant or archived.

---

## Tier 1: Production Languages

### 1. Solidity

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/ethereum/solidity |
| **Description** | The dominant EVM high-level language. Statically typed, contract-oriented, C++/JS-influenced syntax. |
| **Maturity** | Production (deployed on virtually all EVM chains) |
| **Who** | Ethereum Foundation / Solidity team |
| **Current version** | 0.8.x series; compiler backend overhaul underway |
| **Notable 2025-26 development** | "Core Solidity" initiative introduces **SAIL** (Solidity Algebraic Intermediate Language) -- a minimal inner language with a single builtin type (`word`/`uint256`). Generics, algebraic data types, first-class functions planned. Will eventually become Solidity 1.0. See the "Road to Core Solidity" blog post (Oct 2025) and "Core Solidity Deep Dive" (Nov 2025). |

### 2. Vyper

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/vyperlang/vyper |
| **Description** | Python-inspired, intentionally minimalistic. Designed to reduce attack surface by omitting features (no inheritance, no operator overloading, no inline assembly). |
| **Maturity** | Production (Curve Finance, Yearn, Lido components) |
| **Who** | Vyper team (community-maintained, originally Vitalik Buterin's initiative) |
| **Current version** | 0.4.3 (June 2025) |
| **Notable** | Default EVM target updated to Prague. Venom optimizer pipeline adds CSE elimination and dead-store elimination. `@raw_return` decorator and `raw_create()` builtin added. Benchmark contracts typically 5% smaller per release. |

---

## Tier 2: Low-Level / Assembly Languages

### 3. Yul

| Field | Detail |
|-------|--------|
| **Repo** | Part of https://github.com/ethereum/solidity |
| **Description** | Assembly language with high-level control flow (if/switch/for/function). Part of the Solidity toolchain. Intended as a compilation target rather than a standalone authoring language. |
| **Maturity** | Production (used internally by solc's `--via-ir` pipeline) |
| **Who** | Ethereum Foundation / Solidity team |
| **Notable** | No code reuse mechanism (no imports). Compiler written in C++ with plans to migrate to Rust. Serves as the intermediate step for solx's LLVM pipeline. |

### 4. Huff

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/huff-language/huff-rs |
| **Description** | Low-level, macro-based assembly for the EVM. Gives developers direct opcode-level control with a macro system for code reuse. Does not hide the EVM's stack machine. |
| **Maturity** | Production (niche -- used for gas-critical libraries like Weierstrudel, Huffmate) |
| **Who** | Originally Aztec Protocol; rewritten in TypeScript by Jet Jadeja; current Rust version (huff-rs) is community-maintained |
| **History** | Created for Weierstrudel (on-chain elliptic curve arithmetic). Original JS version -> TS rewrite (huffc) -> Rust rewrite (huff-rs). |
| **Ecosystem** | Huffmate library, VSCode extension, starter kits, educational resources. |

### 5. EVM Toolkit (ETK)

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/quilt/etk |
| **Description** | Assembly language with manual stack management and minimal abstractions. Consists of an assembler (`eas`) and disassembler (`disease`). |
| **Maturity** | Experimental |
| **Who** | Quilt (Consensys R&D) |
| **Notable** | Code reuse via `%include` and `%import` directives. Compiler written in Rust. Positioned between raw opcodes and Huff. |

---

## Tier 3: Next-Generation / Experimental Languages

### 6. Plank (formerly Sensei)

| Field | Detail |
|-------|--------|
| **Repo** | https://plankevm.github.io/ (docs site); GitHub org likely at https://github.com/plankevm |
| **Description** | A new EVM language aiming to "empower engineers building complex EVM-based smart contracts." Inspired by Foundry's impact on tooling. Introduces **Sensei IR (SIR)**, a language-agnostic low-level EVM IR designed to be reusable across multiple frontend languages, enabling EVM-specific optimizations. |
| **Maturity** | Alpha / Pre-MVP |
| **Who** | **Philogy** (Philippe Dumonet) and **Oana B.** Originally presented at DevConnect under the name "Sensei," later renamed to Plank. |
| **Roadmap** | Phase I: MVP with end-to-end compilation and comptime (target: end Q1 2026). Phase II: Quality-of-life + core optimizations (~Q2 2026). Phase III: Audit-ready contracts with formal verification. |
| **Key innovation** | SIR as a language-agnostic IR means other EVM language frontends could potentially target SIR and benefit from its optimizer. The compilation pipeline: source -> MLIR -> validation -> SIR -> EVM bytecode. |
| **Related work by Philogy** | **BALLS** (https://github.com/Philogy/balls) -- a DSL for generating optimal EVM bytecode via stack schedule search using Dijkstra scheduling. Also **py-huff** (https://github.com/Philogy/py-huff). |

### 7. Edge

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/refcell/edge-rs |
| **Spec** | https://edge-specification.vercel.app/ |
| **Description** | High-level, strongly statically typed, multi-paradigm DSL for the EVM. Rust-like type system with EVM-native integer types (u8 through u256), explicit data location annotations (`&s` storage, `&t` transient, `&m` memory, `&cd` calldata), traits, generics, pattern matching, and `comptime` for compile-time execution. |
| **Maturity** | Experimental (specification published, compiler WIP) |
| **Who** | **jtriley** (presented at Solidity Summit 2023) |
| **Key innovation** | Bridges the gap between Huff's granularity and Solidity's type safety. Aims to enable constructs no existing language can express: type-checked SSTORE2, in-memory hash maps, compressed ABI encoders, elliptic curve types, nested virtual machines. |
| **Note** | User already knows about this one. |

### 8. Fe

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/ethereum/fe |
| **Website** | https://fe-lang.org/ |
| **Description** | Statically typed EVM language with Rust-inspired syntax and higher-kinded types. Features include `uses` clauses for explicit state access declarations, native package manager with "ingots" (modules). |
| **Maturity** | Alpha (major compiler rewrite in progress; master branch currently not usable for EVM compilation; legacy branch works) |
| **Who** | Originally Ethereum Foundation; now maintained by **Argot Collective** (https://www.argot.org/) |
| **Architecture** | Currently depends on Solidity compiler (solc) via solc-rust for Yul -> EVM bytecode lowering. The rewrite aims to remove this dependency. |
| **2025 update** | Argot Collective published a 2025 roadmap update. The rewrite continues. |

### 9. solx (LLVM-based Solidity Compiler)

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/NomicFoundation/solx (also https://github.com/matter-labs/solx) |
| **Description** | Not a new language but a new LLVM-based backend for Solidity. Reuses the entire solc frontend (lexer, parser, AST), lowers AST to Yul IR, translates to LLVM IR, applies standard LLVM optimizations, then hands off to a custom EVM backend. |
| **Maturity** | Beta (passes internal test suite including Solidity compiler tests, Uniswap V2, Solmate) |
| **Who** | **Matter Labs** (ZKsync) + **Nomic Foundation** (Hardhat) |
| **Key claim** | With 2 person-years of engineering, already produces better runtime gas efficiency than `solc --via-ir --optimize` -- without tuning the LLVM optimizer or implementing EVM-specific optimizations yet. |
| **Future** | Estimates adapting LLVM IR from EVM to RISC-V would require < 10% IR changes. |

---

## Tier 4: Bytecode Generation Tools / DSLs

### 10. BALLS

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/Philogy/balls |
| **Description** | A DSL for generating optimal EVM bytecode. Searches for optimal stack schedules by reordering operations while tracking read/write dependencies. |
| **Maturity** | Experimental tool |
| **Who** | Philogy (same author as Plank) |
| **Notable** | `--dijkstra` flag guarantees optimal scheduling but may not terminate on large inputs. Written in Rust. |

---

## Tier 5: Dormant / Archived / Academic Languages

These are included for completeness. Most are no longer actively maintained but represent interesting design points in the EVM language design space.

### 11. Flint

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/flintlang/flint |
| **Description** | Type-safe, contract-oriented language with caller capabilities (access control) and asset types inspired by linear type theory. |
| **Maturity** | Archived (academic project, no recent activity) |
| **Who** | Imperial College London |

### 12. Bamboo

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/pirapira/bamboo |
| **Description** | Makes state transitions explicit, avoids reentrancy by default. Contract functions transition between named states. |
| **Maturity** | Archived |
| **Who** | Yoichi Hirai (pirapira) |

### 13. Lira

| Field | Detail |
|-------|--------|
| **Description** | Declarative DSL for defining financial contracts on the EVM. |
| **Maturity** | Research/archived |
| **Who** | Academic |

### 14. Elle

| Field | Detail |
|-------|--------|
| **Docs** | https://elle.readthedocs.io/ |
| **Description** | Formally verified EVM compiler implemented in Isabelle (proof assistant). Theorem proves output bytecode behavior matches input program behavior. Frontend (FourL) translates LLL programs to Elle-Core. |
| **Maturity** | Research prototype |
| **Who** | Built on Eth-Isabelle (official EVM specification in Isabelle) |

### 15. LLL (Low-Level Lisp-like Language)

| Field | Detail |
|-------|--------|
| **Description** | Original low-level Ethereum language with Lisp syntax. Predates Solidity. |
| **Maturity** | Deprecated (removed from solc in 2020) |
| **Who** | Gavin Wood / early Ethereum team |

### 16. Serpent

| Field | Detail |
|-------|--------|
| **Description** | Python-like language, predecessor to Vyper. |
| **Maturity** | Deprecated (security issues found; replaced by Vyper) |
| **Who** | Vitalik Buterin |

---

## Adjacent: Non-EVM Languages With EVM Bridges

These do not compile to EVM bytecode natively but are relevant to the broader smart contract language ecosystem.

### Arbitrum Stylus (Rust/C/C++ -> WASM, interops with EVM)

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/OffchainLabs/stylus-sdk-rs |
| **Description** | Dual-VM architecture: WASM contracts run alongside EVM on Arbitrum. Write in Rust/C/C++, full interop with Solidity contracts. 10-70x faster than EVM for compute-heavy workloads. |
| **Maturity** | Production (live on Arbitrum, RedStone reports 30%+ gas savings) |
| **Who** | Offchain Labs (Arbitrum) |

### Solang (Solidity -> WASM for Solana/Polkadot, NOT EVM)

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/hyperledger-solang/solang |
| **Description** | LLVM-based Solidity compiler targeting Solana SBF and Polkadot WASM. Does NOT target EVM. |
| **Maturity** | Production for its target chains |
| **Who** | Hyperledger |

### Warp (Solidity -> Cairo for StarkNet) -- SUNSET

| Field | Detail |
|-------|--------|
| **Repo** | https://github.com/NethermindEth/warp |
| **Description** | Transpiled Solidity to Cairo for StarkNet. |
| **Maturity** | **Sunset** (August 2023). Nethermind concluded auditing 36k lines of transpiler was infeasible. |
| **Who** | Nethermind |

---

## Landscape Summary Table

| Language | Level | Syntax Inspiration | Maturity | Active? | Key Differentiator |
|----------|-------|-------------------|----------|---------|-------------------|
| **Solidity** | High | C++/JS | Production | Yes | Ecosystem dominance, Core Solidity/SAIL coming |
| **Vyper** | High | Python | Production | Yes | Minimalism, Venom optimizer |
| **Yul** | Mid (IR) | Custom | Production | Yes | Solidity's IR, solx's input |
| **Huff** | Low | Macro asm | Production (niche) | Yes | Direct opcode control + macros |
| **ETK** | Low | Assembly | Experimental | Slow | Include/import directives |
| **Plank** | High | TBD (Rust-like?) | Pre-MVP | Yes | SIR (language-agnostic IR), comptime |
| **Edge** | High | Rust | Experimental | Slow | Explicit locations, comptime, traits+generics |
| **Fe** | High | Rust/Python | Alpha (rewrite) | Yes | Higher-kinded types, package manager |
| **solx** | Compiler | (Solidity frontend) | Beta | Yes | LLVM backend, better gas than solc |
| **BALLS** | Tool | DSL | Experimental | Yes | Optimal stack scheduling |
| **Flint** | High | Swift-like | Archived | No | Caller capabilities, linear types |
| **Bamboo** | High | Custom | Archived | No | Explicit state transitions |
| **Elle** | Mid | Isabelle/LLL | Research | No | Formally verified compiler |

---

## Analysis and Observations

### Why new EVM languages struggle to gain traction

1. **Optimizer moat**: Existing compilers (solc, Vyper) have years of optimizer engineering. A new language must reach adequate gas optimization before anyone will use it in production. This is a massive engineering investment.

2. **Tooling ecosystem**: Solidity benefits from Foundry, Hardhat, Remix, Slither, Mythril, etc. A new language starts from zero on all of these.

3. **Auditor familiarity**: Security auditors know Solidity. Introducing a new language means either training auditors or relying on formal verification (which is itself immature for EVM).

4. **The graveyard problem**: Many EVM languages have been attempted and abandoned (Flint, Bamboo, Serpent, LLL, Lira). This creates skepticism about new entrants.

### What could change the calculus

1. **Language-agnostic IRs**: Both Plank (SIR) and Core Solidity (SAIL) are pursuing shared IR strategies. If SIR succeeds as a common backend, new frontend languages could piggyback on its optimizer without building one from scratch.

2. **LLVM for EVM**: solx demonstrates that LLVM's optimizer already beats solc for gas. If LLVM-EVM backends mature, any language with an LLVM frontend (Rust, C, etc.) could theoretically target EVM.

3. **EOF (EVM Object Format)**: The upcoming EOF changes to the EVM instruction set could be a "reset point" where all compilers need significant updates, potentially leveling the playing field.

4. **comptime**: Both Plank and Edge feature compile-time execution. This is a genuinely new capability not available in Solidity or Vyper, and could be the killer feature that drives adoption among power users.

### Recommendations for watching

- **Plank**: The most interesting new entrant due to SIR's language-agnostic design and Philogy's track record in EVM optimization (BALLS, py-huff, gas golf blog posts). Phase I completion (end Q1 2026) will be the first real test.
- **solx**: Already showing results. If it ships a stable release, it could become the default Solidity compiler backend, which would be the single biggest improvement to EVM code quality without requiring anyone to learn a new language.
- **Core Solidity / SAIL**: Long-term play. When it ships (timeline unclear), it effectively creates a new language within Solidity's existing ecosystem, which solves the adoption problem.
- **Edge**: Ambitious design but slower development pace. The specification is thorough. Worth monitoring for whether comptime + explicit locations gains a following.

---

## PlankEVM Deep Dive (User's Specific Interest)

Since the user specifically asked about plankEVM, here is everything gathered:

- **Name**: Plank (formerly Sensei)
- **Website**: https://plankevm.github.io/
- **Authors**: Philogy (Philippe Dumonet) and Oana B.
- **Origin**: First presented at DevConnect under the name "Sensei," later renamed to Plank
- **Philosophy**: Inspired by what Foundry did for EVM tooling; aims to do the same for the compiler layer. Believes Solidity's compiler has been neglected relative to other parts of the dev stack.
- **Core technical contribution**: Sensei IR (SIR) -- a low-level, language-agnostic EVM IR. The intent is that SIR can serve as a shared compilation target for multiple EVM frontend languages, concentrating optimizer effort in one place.
- **Compilation pipeline**: Source -> MLIR -> validation -> Sensei IR (SIR) -> EVM bytecode
- **Roadmap**:
  - Phase I (current, target end Q1 2026): MVP with end-to-end compilation and comptime
  - Phase II (~Q2 2026): Quality-of-life improvements and core optimizations
  - Phase III (future): Audit-ready contracts, formal verification begins
- **Philogy's other EVM work**:
  - BALLS (https://github.com/Philogy/balls): EVM bytecode superoptimizer using Dijkstra scheduling
  - py-huff (https://github.com/Philogy/py-huff): Python Huff implementation
  - Blog posts on gas-optimal function dispatchers and other EVM optimization topics (https://philogy.github.io/)

---

## Sources

- [Plank EVM official site](https://plankevm.github.io/)
- [Philogy GitHub profile](https://github.com/Philogy)
- [BALLS repo](https://github.com/Philogy/balls)
- [Edge specification](https://edge-specification.vercel.app/)
- [Edge-rs repo](https://github.com/refcell/edge-rs)
- [Fe language site](https://fe-lang.org/)
- [Fe repo](https://github.com/ethereum/fe)
- [Argot Collective 2025 roadmap](https://www.argot.org/blog/2025-roadmap-update)
- [Vyper repo](https://github.com/vyperlang/vyper)
- [Vyper release notes](https://docs.vyperlang.org/en/stable/release-notes.html)
- [Huff-rs repo](https://github.com/huff-language/huff-rs)
- [ETK repo](https://github.com/quilt/etk)
- [solx repo (NomicFoundation)](https://github.com/NomicFoundation/solx)
- [solx announcement](https://zksync.mirror.xyz/aCTbO6aDQdrPbUOFR9YMCt24p7-z5KZMMw_GqFz4tpE)
- [Solidity SAIL / Core Solidity deep dive](https://www.soliditylang.org/blog/2025/11/14/core-solidity-deep-dive/)
- [Road to Core Solidity](https://www.soliditylang.org/blog/2025/10/21/the-road-to-core-solidity/)
- [Solidity Summit 2025 recap](https://www.soliditylang.org/blog/2025/12/04/solidity-summit-2025-recap/)
- [Solidity Summit 2023 EVM languages panel](https://www.soliditylang.org/solidity-summit-2023/)
- [jtriley on Edge](https://jtriley.substack.com/p/the-edge-programming-language)
- [Arbitrum Stylus docs](https://docs.arbitrum.io/stylus/gentle-introduction)
- [Stylus SDK Rust repo](https://github.com/OffchainLabs/stylus-sdk-rs)
- [Solang docs](https://solang.readthedocs.io/)
- [Warp sunset announcement](https://medium.com/nethermind-eth/sunsetting-warp-a-farewell-to-the-solidity-to-cairo-transpiler-79e9fdab5f5a)
- [Flint repo](https://github.com/flintlang/flint)
- [Bamboo repo](https://github.com/pirapira/bamboo)
- [Elle docs](https://elle.readthedocs.io/)
- [Smart contract languages curated list](https://github.com/s-tikhomirov/smart-contract-languages)
- [EVM lang design community](https://github.com/evm-lang-design/evm-lang-design)
- [Ethereum.org smart contract languages](https://ethereum.org/developers/docs/smart-contracts/languages/)
- [Alchemy Web3 languages overview](https://www.alchemy.com/overviews/web3-programming-languages)
- [Chainlink smart contract languages](https://chain.link/education-hub/smart-contract-programming-languages)
