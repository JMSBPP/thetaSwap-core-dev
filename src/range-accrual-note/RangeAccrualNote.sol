// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NoteId} from "@range-accrual-note/types/NoteId.sol";
import {NoteSnapshot} from "@range-accrual-note/types/NoteSnapshot.sol";
import {IAccumulatorSource} from "@range-accrual-note/interfaces/IAccumulatorSource.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {TickRange} from "typed-uniswap-v4/types/TickRangeMod.sol";

import {
    mint as erc1155Mint,
    ERC1155Storage,
    getStorage as getERC1155Storage
} from "@compose/token/ERC1155/Mint/ERC1155MintMod.sol";
import {safeTransferFrom as erc1155Transfer} from "@compose/token/ERC1155/Transfer/ERC1155TransferMod.sol";
import {setApprovalForAll as erc1155Approve} from "@compose/token/ERC1155/Approve/ERC1155ApproveMod.sol";

/// @title RangeAccrualNote
/// @notice ERC-1155 token representing a claim on the n/N ratio (growthInside_delta / globalGrowth_delta)
///         for a specific price range and epoch. Settlement creates a two-sided market:
///         short bets on range exit (ratio → 0), long bets on stability (ratio → 1).
/// @dev V1a: Option B transfer settlement — holder earns only from when they received the token.
///      Seller must claim before transferring. V1b migrates to Option C (auto-settle on transfer).
contract RangeAccrualNote {
    // ── Errors ──────────────────────────────────────────────────────

    error ZeroLiquidity();
    error ZeroBalance();
    error NotInitialized();

    // ── Events ──────────────────────────────────────────────────────

    event NoteMinted(
        NoteId indexed id,
        address indexed recipient,
        uint128 amount,
        uint256 entryGrowthInside,
        uint256 entryGlobalGrowth
    );

    event AccrualClaimed(
        NoteId indexed id,
        address indexed holder,
        uint256 ratio
    );

    // ── Storage ─────────────────────────────────────────────────────

    /// @dev Per-NoteId accumulator snapshots, set on first mint.
    mapping(NoteId => NoteSnapshot) private _snapshots;

    /// @dev Per-holder last-claimed growthInside, keyed by raw tokenId.
    mapping(uint256 => mapping(address => uint256)) internal s_lastGrowthInside;

    /// @dev Per-holder last-claimed globalGrowth, keyed by raw tokenId.
    mapping(uint256 => mapping(address => uint256)) internal s_lastGlobalGrowth;

    // ── Core: mint ──────────────────────────────────────────────────

    /// @notice Mint range accrual note tokens.
    /// @dev On first mint for a NoteId, snapshots entry accumulators.
    ///      On first mint for a holder, initializes their last-claimed to current
    ///      so they earn only from their entry point (Option B).
    function mint(
        NoteId id,
        address source,
        PoolId poolId,
        TickRange range,
        uint128 amount,
        address recipient
    ) external {
        id.validate();
        if (amount == 0) revert ZeroLiquidity();

        uint256 tokenId = NoteId.unwrap(id);
        NoteSnapshot storage snap = _snapshots[id];

        // Read current accumulators
        uint256 currentGI = IAccumulatorSource(source).growthInside(poolId, range);
        uint256 currentGG = IAccumulatorSource(source).globalGrowth(poolId);

        // First mint for this NoteId: snapshot entry accumulators
        if (snap.totalLiquidity == 0) {
            snap.entryGrowthInside = currentGI;
            snap.entryGlobalGrowth = currentGG;
        }

        snap.totalLiquidity += amount;

        // First mint for this holder: initialize last-claimed to current
        // so they cannot claim accrual that predates their position.
        // Check balance BEFORE minting — zero means first time.
        ERC1155Storage storage erc = getERC1155Storage();
        if (erc.balanceOf[tokenId][recipient] == 0) {
            s_lastGrowthInside[tokenId][recipient] = currentGI;
            s_lastGlobalGrowth[tokenId][recipient] = currentGG;
        }

        erc1155Mint(recipient, tokenId, uint256(amount), "");

        emit NoteMinted(id, recipient, amount, currentGI, currentGG);
    }

    // ── Core: claim ─────────────────────────────────────────────────

    /// @notice Claim accrued n/N ratio for a note the caller holds.
    /// @dev Computes incremental ratio since caller's last claim.
    ///      Returns WAD-scaled ratio (1e18 = 100% in-range).
    ///      Idempotent: second call with no new growth returns 0.
    function claim(
        NoteId id,
        address source,
        PoolId poolId,
        TickRange range
    ) external returns (uint256 ratio) {
        uint256 tokenId = NoteId.unwrap(id);

        ERC1155Storage storage erc = getERC1155Storage();
        if (erc.balanceOf[tokenId][msg.sender] == 0) revert ZeroBalance();

        NoteSnapshot storage snap = _snapshots[id];
        if (snap.totalLiquidity == 0) revert NotInitialized();

        // Read current accumulators
        uint256 currentGI = IAccumulatorSource(source).growthInside(poolId, range);
        uint256 currentGG = IAccumulatorSource(source).globalGrowth(poolId);

        // If holder was never initialized (received via transfer, Option B):
        // initialize to current — they earn from now, not from note creation
        if (s_lastGlobalGrowth[tokenId][msg.sender] == 0 && currentGG > 0) {
            s_lastGrowthInside[tokenId][msg.sender] = currentGI;
            s_lastGlobalGrowth[tokenId][msg.sender] = currentGG;
            return 0; // First touch after transfer — no accrual yet
        }

        // Compute holder-specific deltas since last claim
        uint256 holderGiDelta;
        uint256 holderGgDelta;
        unchecked {
            holderGiDelta = currentGI - s_lastGrowthInside[tokenId][msg.sender];
            holderGgDelta = currentGG - s_lastGlobalGrowth[tokenId][msg.sender];
        }

        // No new global growth since last claim
        if (holderGgDelta == 0) return 0;

        // Update last-claimed checkpoints
        s_lastGrowthInside[tokenId][msg.sender] = currentGI;
        s_lastGlobalGrowth[tokenId][msg.sender] = currentGG;

        // WAD-scaled ratio: (growthInside_delta * 1e18) / globalGrowth_delta
        ratio = (holderGiDelta * 1e18) / holderGgDelta;

        emit AccrualClaimed(id, msg.sender, ratio);
    }

    // ── Views ───────────────────────────────────────────────────────

    /// @notice Returns the snapshot for a NoteId.
    function snapshots(NoteId id) external view returns (uint256, uint256, uint128) {
        NoteSnapshot storage snap = _snapshots[id];
        return (snap.entryGrowthInside, snap.entryGlobalGrowth, snap.totalLiquidity);
    }

    /// @notice Returns the ERC-1155 balance for an account and token ID.
    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return getERC1155Storage().balanceOf[id][account];
    }

    /// @notice Check operator approval.
    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return getERC1155Storage().isApprovedForAll[owner][operator];
    }

    // ── ERC-1155 mutations ──────────────────────────────────────────

    /// @notice ERC-1155 safe transfer.
    /// @dev V1a: Option B — seller should claim() before transferring.
    ///      V1b will auto-settle on transfer (Option C).
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata
    ) external {
        erc1155Transfer(from, to, id, amount, msg.sender);
    }

    /// @notice Set operator approval.
    function setApprovalForAll(address operator, bool approved) external {
        erc1155Approve(msg.sender, operator, approved);
    }
}
