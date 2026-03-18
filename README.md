<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo/thetaswap-hero-dark.svg" />
    <source media="(prefers-color-scheme: light)" srcset="assets/logo/thetaswap-hero-mono.svg" />
    <img src="assets/logo/thetaswap-hero-dark.svg" width="200" alt="thetaswap" />
  </picture>
</p>

<h2 align="center">thetaswap</h2>

<p align="center">
  Fee concentration insurance for Uniswap V4 passive LPs
</p>

<p align="center">
  <a href="#solidity-fee-concentration-index">Contracts</a> · <a href="#python-econometrics--backtest">Research</a> · <a href="app/">Frontend</a>
</p>

---

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- Python >= 3.13

## Quick Start

```bash
# Clone
git clone https://github.com/wvs-finance/ThetaSwap-core.git
cd ThetaSwap-core

# One-command setup (submodules + venv + deps + Jupyter kernel)
make install

# Run all tests
make sol-test        # Solidity
make test-py         # Python
```

> `make install` initialises only the submodules Foundry actually needs — no
> `--recurse-submodules` required. This keeps clone time under a minute instead
> of 10+ minutes of redundant nested dependencies.

## Solidity (Fee Concentration Index)

```bash
make show-build      # src-only build, no cache, optimized threads (~3s)
make sol-test        # vault + FCI V2 test suites
make sol-test-demo   # NativeV4 FCI integration scenarios (full trace)
```

`sol-test-demo` runs the FCI V2 NativeUniswapV4 integration tests — fixture-driven scenarios that verify delta-plus captures JIT crowd-out on Uniswap V4 pools.

## Python (Econometrics + Backtest)

```bash
# Activate venv
source uhi8/bin/activate

# Run Python tests
make test-py
# or directly:
PYTHONPATH=research pytest research/tests -v

# Execute all notebooks headless
make notebooks
```

Research code lives in `research/`:
- `research/econometrics/` — hazard model, duration model, ingestion
- `research/backtest/` — insurance backtest engine
- `research/data/` — cached Dune query results
- `research/notebooks/` — reproducible result notebooks
- `research/tests/` — Python test suite

### Manual Python Setup (without Make)

```bash
uv venv uhi8 --python 3.13
source uhi8/bin/activate
uv pip install --python uhi8/bin/python -e ".[dev]"

# For notebooks: register a Jupyter kernel
python -m ipykernel install --user --name=thetaswap \
    --env PYTHONPATH "$(pwd)/research"
```

### Running Notebooks

Notebooks expect a kernel with `PYTHONPATH` pointing to `research/`. The `make install` command sets this up automatically. To run interactively:

```bash
source uhi8/bin/activate
jupyter lab --notebook-dir=research/notebooks
```

Select the **thetaswap** kernel when opening notebooks.

## Project Structure

```
src/
  fee-concentration-index/     FCI V1 hook contract
  fee-concentration-index-v2/  FCI V2 (delta-plus, reactive dispatch)
  fci-token-vault/             Insurance vault (ERC-4626)
  protocol-adapter/            Multi-protocol adapter layer
  libraries/                   Shared Solidity libraries
  types/                       Shared type extensions
  utils/                       Test/deploy utilities
test/
  fee-concentration-index/     FCI V1 tests
  fee-concentration-index-v2/  FCI V2 + integration tests
  fci-token-vault/             Vault tests (unit, fuzz, integration)
research/
  econometrics/                Hazard + duration models
  backtest/                    Insurance backtest engine
  data/                        Cached Dune query data
  notebooks/                   Result notebooks (4)
  tests/                       Python tests (pytest)
specs/                         LaTeX specs + econometric model
foundry-script/                Forge deployment scripts
docs/plans/                    Implementation plans
lib/                           Foundry dependencies (submodules)
```
