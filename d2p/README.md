# d2p — ThetaSwap Deployment Pipeline

Thin Rust CLI wrapping Foundry's `forge create` and `cast send --create` for deploying ThetaSwap reactive contracts. Automatic fallback when `forge create` fails.

## Install

```bash
cd d2p
cargo build --release
# Binary at d2p/target/release/d2p
```

**Requirements:** [Foundry](https://getfoundry.sh) (`forge` and `cast` on PATH).

## Usage

```bash
d2p ts reactive uniswap-v3 \
  --rpc-url https://rpc.sepolia.org \
  --private-key $ETH_PRIVATE_KEY \
  --callback 0xYourCallbackProxy
```

On success, prints the deployed address and tx hash to stdout.

### Flags

| Flag | Env Var | Default | Description |
|------|---------|---------|-------------|
| `--rpc-url` | `ETH_RPC_URL` | required | JSON-RPC endpoint |
| `--private-key` | `ETH_PRIVATE_KEY` | required | Hex-encoded private key |
| `--callback` | — | required | Callback proxy address |
| `--value` | — | `10react` | Value sent with deploy |
| `--project` | — | `.` (CWD) | Solidity project root |

### How it works

1. Runs `forge create --json --broadcast --legacy` with the contract path
2. If forge fails, retries with `cast send --create` using compiled bytecode
3. Verifies on-chain receipt (`cast receipt --json`, status `0x1`)
4. Prints address + tx hash to stdout

### Exit codes

- `0` — deploy verified on-chain
- `1` — deploy failed (error on stderr)
- `2` — invalid arguments (clap)

## Test

```bash
cd d2p && cargo test
# 28 tests, 0 failures
```
