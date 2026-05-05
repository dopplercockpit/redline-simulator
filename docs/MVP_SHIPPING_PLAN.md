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

## Patch 2 Goal

Patch 2 adds the local-first player decision loop for Airport CFO. The phone inbox now presents one JSON-driven weekly action card, the player chooses one option, consequences route through `DecisionResolver`, ledger/statements update, and the week advances. After week 4, the existing month-close mission appears through the mission inbox.

## Patch 2 Files Changed

- `res://data/actions/flightpath/action_cards_v1.json`
- `res://data/scenarios/flightpath/scenario_001.json`
- `res://data/finance/coa_airport_v1.json`
- `res://engine/DecisionResolver.gd`
- `res://engine/GameManager.gd`
- `res://engine/ledger.gd`
- `res://scripts/panels/InboxPanel.gd`
- `res://scenes/panels/InboxPanel.tscn`
- `res://ui/FinancialPanel.gd`
- `res://docs/CANONICAL_PRODUCT.md`
- `res://docs/MVP_SHIPPING_PLAN.md`

## Patch 2 Acceptance Tests

- CFO Office loads and the phone opens the inbox without backend access.
- Week 1 shows `CARD_W1_CASH_TRIAGE`.
- Choosing a card option posts any configured ledger transactions through `DecisionResolver`.
- The same card cannot be applied twice because `LoopState.flags["card_completed.<CARD_ID>"]` is set.
- The inbox does not allow week advance while an active card is unanswered.
- Pressing `Advance Week` runs `GameManager.advance_week(false)`.
- Weeks 2, 3, and 4 show the scheduled cards.
- FinancialPanel shows normal airport weekly postings plus action-card ledger impact.
- Route Incentive Expense and Professional Fees / Close Prep Expense are visible in income statement output.
- After week 4 advances, the month-close mission is queued and the inbox offers `Enter Boardroom`.
- No backend, LLM, npm, or Python service is required for the local MVP.

## Patch 3 Recommendation

Patch 3 should add richer airport operating context around the weekly cards: compact KPI/status widgets in the CFO office, a clearer history of chosen actions, and a small runway of future card definitions for route incentives, staffing/service quality, covenant pressure, and capex deferral.

## Patch 3 — Boardroom, Unlocks, Status HUD, and Month 1 Scorecard

### Goal

Patch 3 makes the Month 1 loop visibly playable. The player sees weekly decision consequences in a persistent HUD, completes the month-close boardroom quiz, receives mission points/audit impact, has scenario objectives evaluated, and sees a Month 1 scorecard with any tool unlocks.

### Files Changed

- `res://engine/GameManager.gd`
- `res://scenes/cfo_office.gd`
- `res://scripts/panels/InboxPanel.gd`
- `res://ui/BoardroomQuiz.gd`
- `res://ui/BoardroomQuiz.tscn`
- `res://ui/StatusHUD.gd`
- `res://ui/StatusHUD.tscn`
- `res://ui/MonthScorecard.gd`
- `res://ui/MonthScorecard.tscn`
- `res://docs/CANONICAL_PRODUCT.md`
- `res://docs/MVP_SHIPPING_PLAN.md`

### Acceptance Tests

- CFO Office loads with a visible StatusHUD.
- StatusHUD shows week, month, cash, points, audit score, reputation, ops risk, and unlocks.
- Week 1 action card selection updates HUD through `GameManager.state_updated`.
- Week advance updates the displayed week/month.
- Week 4 advance queues the month-close mission.
- Boardroom quiz completion still awards mission points and audit score through `MissionManager`.
- `GameManager` evaluates `scenario_001` objectives after month-close mission completion.
- If cash is at least `$900,000` by week 4, `obj_cash` awards `150` points once and unlocks `DEBT_DESK`.
- Objective rewards cannot be duplicated after the objective is checked.
- MonthScorecard appears after month-close mission completion.
- MonthScorecard displays cash, operating margin, DSCR, points, audit score, reputation, ops risk, completed missions, unlocks, and objective results.
- After `DEBT_DESK` unlocks, the inbox can show a Debt Desk unlocked stub.
- No backend or LLM call is required.

### Patch 4 Recommendation

Patch 4 should turn `DEBT_DESK` from a visible stub into a small refinancing decision tool: term extension, covenant waiver, interest cost tradeoff, and debt-service impact posted through the same ledger-first resolver path.
