# Patch 8 - Audit Room v1 + Run Review

## Purpose

Audit Room turns the `AUDIT_ROOM` unlock into a local review and remediation tool. It gives the player a readable run audit trail after Month 3 and allows one control remediation action.

## Run Review Snapshot

`GameManager.get_run_review_snapshot()` consolidates loop state, financial statements, recent ledger activity, contract review results, objective results, and any prior Audit Room remediation. The panel receives duplicate snapshots so it can render without mutating simulation state.

## Remediation Choices

Remediations are defined in `res://data/tools/audit_room/audit_remediations_v1.json`.

- `CONTROL_EVIDENCE_CLEANUP` funds evidence and reconciliation cleanup.
- `MANAGEMENT_REP_PACKAGE` funds board/auditor explanation work.
- `ACCEPT_AUDIT_RISK` spends nothing and carries residual risk forward.

## Ledger Treatment

Costed remediation choices post through `DecisionResolver` as ledger transactions. They debit `5300 Professional Fees / Close Prep Expense` and credit `1000 Cash`. Statements regenerate from the ledger after posting.

## Duplicate Prevention

Patch 8 allows one Audit Room remediation per MVP run. `DecisionResolver` sets `LoopState.flags["tool_used.AUDIT_ROOM"] = true` after a successful remediation and rejects repeat attempts.

## Patch 9 Recommendation

Patch 9 should add persistence and an end-of-run export/review summary so the completed Month 1-3 arc can be replayed, resumed, and reviewed outside the active office scene.
