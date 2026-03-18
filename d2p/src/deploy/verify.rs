// verify.rs — cast receipt --json status check
// Source: verified cast receipt --json on anvil; status field is "0x1" string (not "1 (success)")
//
// IMPORTANT (Pitfall 3 from RESEARCH.md):
//   `cast receipt <TXHASH> status` (positional field) returns human string "1 (success)".
//   `cast receipt <TXHASH> --json` returns {"status":"0x1",...}.
//   Only the --json path is machine-parseable. This module uses --json exclusively.
//   The string "0x1" is the ONLY accepted success value; "1 (success)" must be rejected.

/// Parse the stdout bytes of `cast receipt --json` and verify the transaction succeeded.
///
/// Returns `Ok(())` when `status == "0x1"`.
/// Returns `Err` with actionable message when status is non-success or the field is absent.
fn parse_receipt_status(stdout: &[u8]) -> anyhow::Result<()> {
    let v: serde_json::Value = serde_json::from_slice(stdout)
        .map_err(|e| anyhow::anyhow!("failed to parse cast receipt JSON: {e}"))?;
    match v["status"].as_str() {
        Some("0x1") => Ok(()),
        Some(s) => anyhow::bail!("transaction reverted on-chain (status={s})"),
        None => anyhow::bail!("cast receipt JSON missing status field"),
    }
}

/// Verify a deployment transaction was mined successfully by inspecting the on-chain receipt.
///
/// Spawns: `cast receipt --rpc-url <rpc_url> <tx_hash> --json`
/// Arg order verified in RESEARCH.md Pattern 3.
///
/// Returns `Ok(())` when receipt status is "0x1".
/// Returns `Err` when:
///   - cast is not on PATH (IO error)
///   - cast exits non-zero (e.g., tx not yet mined)
///   - receipt JSON is missing or has non-"0x1" status
pub fn verify(tx_hash: &str, rpc_url: &str) -> anyhow::Result<()> {
    let out = std::process::Command::new("cast")
        .args(["receipt", "--rpc-url", rpc_url, tx_hash, "--json"])
        .output()
        .map_err(|e| anyhow::anyhow!("cast receipt: cast not found: {e}"))?;

    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        anyhow::bail!("cast receipt failed: {}", stderr);
    }

    parse_receipt_status(&out.stdout)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Receipt with status "0x1" — must return Ok(()).
    #[test]
    fn test_verify_receipt_success() {
        let stdout = br#"{"status":"0x1","contractAddress":"0xABC"}"#;
        let result = parse_receipt_status(stdout);
        assert!(result.is_ok(), "status 0x1 must be accepted; got: {:?}", result.err());
    }

    /// Receipt with status "0x0" — must return Err containing "reverted".
    #[test]
    fn test_verify_receipt_reverted() {
        let stdout = br#"{"status":"0x0","contractAddress":null}"#;
        let result = parse_receipt_status(stdout);
        assert!(result.is_err(), "status 0x0 must be rejected");
        let msg = result.unwrap_err().to_string();
        assert!(
            msg.contains("reverted"),
            "error message must contain 'reverted'; got: {msg}"
        );
    }

    /// Receipt JSON missing the status field — must return Err containing "missing status".
    #[test]
    fn test_verify_receipt_missing_status() {
        let stdout = br#"{"blockNumber":"1"}"#;
        let result = parse_receipt_status(stdout);
        assert!(result.is_err(), "missing status field must produce error");
        let msg = result.unwrap_err().to_string();
        assert!(
            msg.contains("missing status"),
            "error message must contain 'missing status'; got: {msg}"
        );
    }

    /// Receipt with human-readable string "1 (success)" — must be rejected (Pitfall 3).
    /// Only the hex string "0x1" is a valid success indicator.
    #[test]
    fn test_verify_rejects_human_string() {
        let stdout = br#"{"status":"1 (success)"}"#;
        let result = parse_receipt_status(stdout);
        assert!(
            result.is_err(),
            "human-readable '1 (success)' must NOT be accepted; only '0x1' is valid"
        );
    }
}
