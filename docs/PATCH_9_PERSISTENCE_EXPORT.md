# Patch 9 - Persistence + End-of-Run Export

## Save Schema

Patch 9 adds a full-run JSON save at `user://flightpath_run_save.json`:

```json
{
  "schema_version": "1.0",
  "saved_at": 1710000000,
  "scenario": {},
  "objectives_evaluated": {},
  "loop_state": {},
  "financial_state": {}
}
```

`loop_state` stores points, audit score, week/month, inbox, completed missions, flags, memory, unlocks, and risk values. `financial_state` stores cash, ledger, COA, airport/commercial/contracts/economy state, finance, debt stack, covenants, KPIs, and metadata. The ledger remains the source of truth.

## Load Flow

`GameManager.load_run()` parses and validates the JSON before mutating the active run. It restores the scenario config, objective cache, financial state, and loop state directly. It then rebinds `MissionManager` with the restored `LoopState` using `bind_restored_state()`, which intentionally skips the older partial ConfigFile load path.

## Autosave Triggers

Autosave runs after:

- successful `submit_intent()` calls,
- week advancement,
- month-close mission completion,
- reset.

The initial scenario load does not automatically overwrite an existing save on boot.

## Export Summary

`GameManager.export_run_summary()` writes `user://flightpath_run_summary.md`. The Markdown export includes current position, financial snapshot, objectives, contract reviews, Audit Room remediation, recent ledger transactions, trial balance, timestamp, and review notes.

## Reset Behavior

`GameManager.reset_run()` reloads the canonical Flightpath scenario, rebinds MissionManager, clears the older MissionManager partial save where available, and writes a fresh full-run save. The full JSON save is authoritative after Patch 9.

## Known Limitations

The save file is local only. It is not encrypted, synced, or tied to a user account. Export is a readable teaching summary, not a formal accounting report.
