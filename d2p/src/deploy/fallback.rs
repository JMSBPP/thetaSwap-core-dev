// fallback.rs — cast send --create fallback deployment strategy
// Source: verified cast send --create --help and live test on Foundry v1.5.1
//
// CRITICAL constraint (DEP-02, Pitfall 2):
//   All flags (--rpc-url, --private-key, --value, --json) must appear BEFORE --create.
//   --create is a subcommand of cast send, not a flag. Placing any option after --create
//   causes: `error: unexpected argument '--rpc-url' found`.
//
// CRITICAL constraint (DEP-03):
//   NO --legacy flag on this path. cast send uses EIP-1559 by default.
//   Lasna accepts both EIP-1559 and legacy transactions.
//
// Bytecode source (Pitfall 5):
//   Read from {project_dir}/out/{ContractName}.sol/{ContractName}.json at .bytecode.object
//   This file is produced by `forge build` and must exist before run() is called.
//   Missing artifact returns an actionable error directing the user to run `forge build`.
//
// ENV constraint: ETH_RPC_URL is removed from subprocess environment (same as primary.rs).
use crate::{
    deploy::{DeployOutput, DeployParams},
    errors::D2pError,
};
use anyhow::Context;

/// Deserialization target for `cast send --create --json` stdout.
///
/// Verified output shape on Foundry v1.5.1-stable (full transaction receipt):
/// `{"contractAddress":"0x...","transactionHash":"0x...","status":"0x1",...}`
///
/// Only address and tx_hash are extracted here; receipt status verification
/// is handled separately in verify.rs (Plan 02-02).
#[derive(serde::Deserialize)]
struct CastSendJson {
    #[serde(rename = "contractAddress")]
    contract_address: String,
    #[serde(rename = "transactionHash")]
    transaction_hash: String,
}

/// Run `cast send --create` with bytecode from the forge artifact and return deployed address + tx hash.
///
/// Fails with actionable error if the forge artifact is missing (Pitfall 5).
/// Fails with `D2pError::ProcessNotFound` if `cast` is not on PATH.
/// Fails with `D2pError::NonZeroExit` if cast exits non-zero.
/// Fails with `D2pError::ParseFailure` if stdout is not valid CastSendJson.
pub fn run(params: &DeployParams) -> anyhow::Result<DeployOutput> {
    let bytecode = read_bytecode(params)?;
    let args = build_args(params, &bytecode);

    let out = std::process::Command::new("cast")
        .args(&args)
        .current_dir(&params.project_dir)
        // Remove ETH_RPC_URL so it cannot shadow the explicit --rpc-url flag (Pitfall 6)
        .env_remove("ETH_RPC_URL")
        .output()
        .map_err(|e| match e.kind() {
            std::io::ErrorKind::NotFound => D2pError::ProcessNotFound("cast".to_string()),
            _ => D2pError::NonZeroExit {
                stderr: e.to_string(),
            },
        })?;

    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr).into_owned();
        return Err(D2pError::NonZeroExit { stderr }.into());
    }

    let stdout = String::from_utf8_lossy(&out.stdout);
    let parsed: CastSendJson = serde_json::from_str(&stdout)
        .map_err(|e| D2pError::ParseFailure(format!("cast JSON: {e}")))?;

    Ok(DeployOutput {
        address: parsed.contract_address,
        tx_hash: parsed.transaction_hash,
    })
}

/// Read the compiled bytecode from the forge artifact directory.
///
/// Artifact path: `{project_dir}/out/{ContractName}.sol/{ContractName}.json`
/// Bytecode field: `.bytecode.object` (includes 0x prefix — passed as-is to cast).
///
/// Returns actionable error including "forge build" if the artifact file is missing (Pitfall 5).
fn read_bytecode(params: &DeployParams) -> anyhow::Result<String> {
    // Contract name is the part after ':' in contract_path, e.g. "UniswapV3Reactive"
    let contract_name = params
        .contract_path
        .split(':')
        .last()
        .ok_or_else(|| anyhow::anyhow!("invalid contract_path: {}", params.contract_path))?;

    let artifact = params
        .project_dir
        .join("out")
        .join(format!("{contract_name}.sol"))
        .join(format!("{contract_name}.json"));

    let content = std::fs::read_to_string(&artifact).with_context(|| {
        format!(
            "artifact not found at {} — run `forge build` from {} first",
            artifact.display(),
            params.project_dir.display()
        )
    })?;

    let v: serde_json::Value = serde_json::from_str(&content)
        .with_context(|| format!("failed to parse artifact JSON at {}", artifact.display()))?;

    let bytecode = v["bytecode"]["object"]
        .as_str()
        .ok_or_else(|| anyhow::anyhow!("bytecode.object missing in {}", artifact.display()))?;

    Ok(bytecode.to_string())
}

/// Build the argument vector for `cast send --create`.
///
/// Arg order is critical (DEP-02, Pitfall 2):
///   [send, --rpc-url, ..., --private-key, ..., --value, ..., --json,
///    --create, bytecode, constructor(address), callback]
///
/// All flags MUST precede --create. No --legacy (DEP-03).
fn build_args(params: &DeployParams, bytecode: &str) -> Vec<String> {
    vec![
        "send".to_string(),
        "--rpc-url".to_string(),
        params.rpc_url.clone(),
        "--private-key".to_string(),
        params.private_key.clone(),
        "--value".to_string(),
        params.value.clone(),
        "--json".to_string(),
        // --create is a subcommand — all flags must precede it (Pitfall 2)
        "--create".to_string(),
        bytecode.to_string(),
        // cast ABI-encodes constructor args from SIG + positional ARGS
        "constructor(address)".to_string(),
        params.callback.clone(),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn test_params() -> DeployParams {
        DeployParams {
            rpc_url: "https://rpc.example.com".to_string(),
            private_key: "0xdeadbeef".to_string(),
            callback: "0xcallback000000000000000000000000000000".to_string(),
            value: "10react".to_string(),
            contract_path: "src/UniswapV3Reactive.sol:UniswapV3Reactive".to_string(),
            project_dir: PathBuf::from("/tmp"),
        }
    }

    const DUMMY_BYTECODE: &str = "0x6080604052";

    /// DEP-03: --legacy must NOT appear anywhere in the cast send args.
    #[test]
    fn test_cast_args_no_legacy() {
        let args = build_args(&test_params(), DUMMY_BYTECODE);
        assert!(
            !args.iter().any(|a| a == "--legacy"),
            "fallback build_args must NOT include '--legacy' (DEP-03)"
        );
    }

    /// DEP-02 + Pitfall 2: All flags appear before --create; bytecode immediately after --create;
    /// "constructor(address)" after bytecode; callback is last.
    #[test]
    fn test_cast_args_order() {
        let args = build_args(&test_params(), DUMMY_BYTECODE);

        // Locate --create index
        let create_pos = args
            .iter()
            .position(|a| a == "--create")
            .expect("--create must be present in fallback args");

        // All these flags must appear BEFORE --create
        for flag in &["--rpc-url", "--private-key", "--value", "--json"] {
            let flag_pos = args
                .iter()
                .position(|a| a == *flag)
                .unwrap_or_else(|| panic!("{flag} must be present in fallback args"));
            assert!(
                flag_pos < create_pos,
                "{flag} at index {flag_pos} must appear before --create at index {create_pos}"
            );
        }

        // Bytecode is immediately after --create
        assert_eq!(
            args[create_pos + 1],
            DUMMY_BYTECODE,
            "bytecode must be immediately after --create"
        );

        // constructor(address) follows bytecode
        assert_eq!(
            args[create_pos + 2],
            "constructor(address)",
            "constructor sig must follow bytecode"
        );

        // callback is last
        let len = args.len();
        assert_eq!(
            args[len - 1],
            "0xcallback000000000000000000000000000000",
            "callback must be last element"
        );
    }

    /// JSON parsing: CastSendJson deserializes camelCase fields correctly.
    #[test]
    fn test_parse_cast_json() {
        let json =
            r#"{"contractAddress":"0xABC","transactionHash":"0xDEF","status":"0x1"}"#;
        let parsed: CastSendJson =
            serde_json::from_str(json).expect("should deserialize valid cast send JSON");
        assert_eq!(parsed.contract_address, "0xABC");
        assert_eq!(parsed.transaction_hash, "0xDEF");
    }

    /// Pitfall 5: Missing artifact file returns error containing "forge build".
    #[test]
    fn test_read_bytecode_missing_artifact() {
        let params = DeployParams {
            project_dir: PathBuf::from("/nonexistent/path/that/does/not/exist"),
            ..test_params()
        };
        let result = read_bytecode(&params);
        assert!(result.is_err(), "read_bytecode should fail when artifact is missing");
        let err_msg = result.unwrap_err().to_string();
        assert!(
            err_msg.contains("forge build"),
            "error message must contain 'forge build' for actionability; got: {err_msg}"
        );
    }

    /// read_bytecode returns Err when JSON exists but bytecode.object is absent.
    #[test]
    fn test_read_bytecode_missing_field() {
        // Write a temporary artifact JSON with no bytecode.object field
        let dir = std::env::temp_dir();
        let contract_name = "TestContractMissingField";
        let sol_dir = dir.join(format!("out/{contract_name}.sol"));
        std::fs::create_dir_all(&sol_dir).expect("create temp artifact dir");
        let artifact_path = sol_dir.join(format!("{contract_name}.json"));
        // JSON with bytecode present but object field missing
        std::fs::write(&artifact_path, r#"{"bytecode":{}}"#)
            .expect("write temp artifact JSON");

        let params = DeployParams {
            contract_path: format!("src/{contract_name}.sol:{contract_name}"),
            project_dir: dir.clone(),
            ..test_params()
        };

        let result = read_bytecode(&params);
        assert!(result.is_err(), "read_bytecode should fail when bytecode.object is missing");
        let err_msg = result.unwrap_err().to_string();
        assert!(
            err_msg.contains("bytecode.object missing"),
            "error must mention 'bytecode.object missing'; got: {err_msg}"
        );

        // Cleanup
        let _ = std::fs::remove_file(&artifact_path);
        let _ = std::fs::remove_dir(&sol_dir);
    }
}
