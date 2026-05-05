# MVP Shipping Plan

## Patch 1 Goal

Patch 1 makes Airport CFO / Flightpath the canonical Godot MVP path. Weekly advancement now uses airport ledger postings, opening balances come from the airport scenario, financial panels show airport CFO statements, and month close uses accounting questions instead of airline operating metrics.

## Patch 1 Files Changed

- `res://engine/state.gd`
- `res://engine/finance.gd`
- `res://engine/ledger.gd`
- `res://engine/DecisionResolver.gd`
- `res://engine/GameManager.gd`
- `res://scenes/cfo_office.gd`
- `res://ui/FinancialPanel.gd`
- `res://data/missions/month_close_v1.json`
- `res://docs/CANONICAL_PRODUCT.md`
- `res://docs/MVP_SHIPPING_PLAN.md`

## Acceptance Tests

- Project opens under Godot 4.5.
- `RSE` loads `res://data/scenarios/flightpath/scenario_001.json`.
- Airport, commercial, finance, contracts, and economy state load without errors.
- Opening cash comes from GL `1000` in `finance.opening_balances`.
- Advancing one week posts balanced ledger transactions.
- Ledger trial balance changes after week advance.
- Financial panel displays airport CFO labels.
- Month close report contains `income_statement`, `balance_sheet`, `cash_flow`, and `kpis`.
- Month close mission no longer mentions airline metrics.
- CFO office welcomes the player to Flightpath CFO.
- `redline_scenarios_v3.json` is not the active scenario source.
- No backend changes are required.

## Next Patch Recommendation

Patch 2 should add decision-specific airport actions that alter ledger postings and operating assumptions, such as vendor payment timing, route incentives, concession renegotiation, staffing/service tradeoffs, and debt covenant pressure.
