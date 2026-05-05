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

## Patch 4 — Debt Desk v1

### Goal

Patch 4 turns the `DEBT_DESK` unlock into a working local financing tool. After Month 1, the inbox can present financing offers that post debt proceeds to the ledger, add debt stack items, update financial statements, and increase future weekly interest expense.

### Files Changed

- `res://data/tools/debt_desk/debt_offers_v1.json`
- `res://data/finance/coa_airport_v1.json`
- `res://engine/DecisionResolver.gd`
- `res://engine/GameManager.gd`
- `res://engine/ledger.gd`
- `res://engine/finance.gd`
- `res://scripts/panels/InboxPanel.gd`
- `res://ui/FinancialPanel.gd`
- `res://ui/StatusHUD.gd`
- `res://ui/StatusHUD.tscn`
- `res://ui/MonthScorecard.gd`
- `res://docs/PATCH_4_DEBT_DESK.md`
- `res://docs/CANONICAL_PRODUCT.md`
- `res://docs/MVP_SHIPPING_PLAN.md`

### Acceptance Tests

- CFO Office loads under Godot 4.5.
- StatusHUD displays cash and total debt.
- After Week 4 and the Boardroom quiz, passing the cash objective unlocks `DEBT_DESK`.
- Opening the phone after unlock shows Debt Desk financing offers.
- `DRAW_REVOLVER_250K` posts Dr `1000` / Cr `2300` for `$250,000`.
- Revolver draw increases cash, short-term debt, total debt, and adds `REVOLVER_DRAW_001` to `debt_stack`.
- `DRAW_TERM_LOAN_750K` posts Dr `1000` / Cr `2400` for `$750,000` and Dr `5300` / Cr `1000` for the `$15,000` fee.
- Term loan draw increases term debt, total debt, and adds `TERMLOAN_SUPP_001` to `debt_stack`.
- Future weekly interest expense increases because airport weekly finance sums every valid debt stack item.
- Debt Desk draw cannot be executed twice in the same MVP run.
- `DECLINE_DEBT` posts no ledger entries and does not consume the one draw.
- FinancialPanel shows Short-Term Debt / Revolver, Debt - Term Loan, and Total Debt.
- MonthScorecard shows Total Debt.
- No backend or LLM call is required.

### Patch 5 Recommendation

Patch 5 should add repayment/refinancing choices and covenant pressure: optional revolver repayment, term loan amendment, covenant waiver fees, and board feedback when leverage or DSCR deteriorates.

## Patch 5 — Scenario 2 / Month 2: Route Incentive Offer

### Goal

Patch 5 extends the continuous Airport CFO MVP into Month 2. BudgetAir proposes added route activity if the airport funds an incentive package, forcing the player to balance growth, incentive expense, liquidity, service capacity, and board explanation.

### Files Changed

- `res://data/actions/flightpath/action_cards_v1.json`
- `res://data/scenarios/flightpath/scenario_001.json`
- `res://data/missions/month_close_route_incentive_v1.json`
- `res://engine/MissionManager.gd`
- `res://engine/GameManager.gd`
- `res://scripts/panels/InboxPanel.gd`
- `res://ui/MonthScorecard.gd`
- `res://docs/PATCH_5_ROUTE_INCENTIVE.md`
- `res://docs/CANONICAL_PRODUCT.md`
- `res://docs/MVP_SHIPPING_PLAN.md`

### Acceptance Tests

- Week 1-4 action cards still work.
- Month 1 close still queues and launches the generic boardroom mission.
- Month 1 cash objective still unlocks `DEBT_DESK` once.
- Debt Desk remains available after Month 1 and does not block Week 5.
- Week 5 shows `CARD_W5_BUDGETAIR_OFFER`.
- Week 6 shows `CARD_W6_ROUTE_ECONOMICS`.
- Week 7 shows `CARD_W7_SERVICE_CAPACITY`.
- Week 8 shows `CARD_W8_BOARD_PREP_ROUTE_INCENTIVE`.
- Week 8 close queues `MISSION_MONTH_CLOSE_ROUTE_INCENTIVE_V1_M2`.
- Month 2 boardroom questions focus on route incentive economics.
- Completing Month 2 close evaluates `obj_route_incentive` and `obj_cash_month2`.
- Month 2 objectives do not evaluate before week 8.
- Objective rewards cannot duplicate.
- Month 2 scorecard displays objective id, metric, operator, target, result, reward, unlocks, and note for each evaluated objective.
- Total debt remains visible in HUD and scorecard.
- No backend or LLM call is required.

### Patch 6 Recommendation

Patch 6 should add Contract Review as the next unlocked tool, using the Month 2 reward to introduce carrier agreement terms, clawback language, minimum service commitments, and board-ready contract risk explanations.

## Patch 6 — Contract Review v1

### Goal

Patch 6 turns the `CONTRACT_REVIEW` unlock into a local governance tool. After Month 2, the contract cabinet opens a BudgetAir incentive agreement review where the player chooses contract handling, posts any review cost through the ledger, updates loop risk, and stores a contract risk result.

### Files Changed

- `res://data/contracts/flightpath/budgetair_route_incentive_v1.txt`
- `res://data/tools/contract_review/contract_reviews_v1.json`
- `res://engine/DecisionResolver.gd`
- `res://engine/GameManager.gd`
- `res://scenes/cfo_office.gd`
- `res://ui/ContractPanel.gd`
- `res://ui/StatusHUD.gd`
- `res://ui/MonthScorecard.gd`
- `res://docs/PATCH_6_CONTRACT_REVIEW.md`
- `res://docs/CANONICAL_PRODUCT.md`
- `res://docs/MVP_SHIPPING_PLAN.md`

### Acceptance Tests

- Clicking the contract cabinet before `CONTRACT_REVIEW` unlocks shows a locked message.
- After Month 2 objective success, StatusHUD shows `CONTRACT_REVIEW`.
- Clicking the contract cabinet after unlock opens the BudgetAir contract review.
- The panel displays title, sender, body, substituted contract text, and choice buttons.
- `ACCEPT_AS_IS` posts no ledger entry, stores high risk, and applies loop risk changes.
- `ADD_CLAWBACK_AND_SERVICE_COMMITMENT` posts Dr `5300` / Cr `1000` for `$25,000`, stores low risk, and updates statements/HUD.
- `ADD_CLAWBACK_ONLY` posts Dr `5300` / Cr `1000` for `$10,000` and stores medium risk.
- `ESCALATE_TO_BOARD` posts no ledger entry and stores escalated review status.
- The same contract review cannot be applied twice.
- Reopening the contract cabinet after completion shows completed status.
- MonthScorecard can display stored contract reviews.
- No backend or LLM call is required.

### Patch 7 Recommendation

Patch 7 should make `CONTRACT_REVIEW` consequences matter in Month 3: service commitment compliance, clawback recovery, route underperformance, board confidence, and covenant pressure tied to the selected agreement terms.

## Patch 7 — Month 3: Compliance, Clawback, and Audit Pressure

### Goal

Patch 7 extends Flightpath CFO into Month 3 and makes the BudgetAir contract review matter. BudgetAir underperforms, the player handles clawback or fallout, compliance pressure rises, covenant communication becomes explicit, and the Month 3 boardroom evaluates governance discipline.

### Files Changed

- `res://data/actions/flightpath/action_cards_v1.json`
- `res://data/scenarios/flightpath/scenario_001.json`
- `res://data/finance/coa_airport_v1.json`
- `res://data/missions/month_close_compliance_v1.json`
- `res://engine/DecisionResolver.gd`
- `res://engine/GameManager.gd`
- `res://engine/MissionManager.gd`
- `res://engine/ledger.gd`
- `res://scripts/panels/InboxPanel.gd`
- `res://ui/ContractPanel.gd`
- `res://ui/FinancialPanel.gd`
- `res://docs/PATCH_7_COMPLIANCE_AUDIT.md`
- `res://docs/CANONICAL_PRODUCT.md`
- `res://docs/MVP_SHIPPING_PLAN.md`

### Acceptance Tests

- `ContractPanel.gd` parses cleanly after the indentation preflight fix.
- Week 1-8 flow still works and Month 2 can unlock `CONTRACT_REVIEW`.
- Contract Review still stores the selected BudgetAir review result.
- Week 9 shows `CARD_W9_BUDGETAIR_MISSES_TARGET`.
- If contract review selected a moderate or strong clawback, `ENFORCE_CLAWBACK` posts Dr `1000` / Cr `4300` for `$35,000`.
- If contract review accepted weak terms, `ENFORCE_CLAWBACK` is rejected by `DecisionResolver` with unavailable feedback.
- FinancialPanel shows Route Incentive Clawback Recovery.
- Weeks 10-12 show compliance, covenant, and board governance cards.
- Week 12 close queues `MISSION_MONTH_CLOSE_COMPLIANCE_V1_M3`.
- Completing Month 3 boardroom evaluates `obj_audit_month3`, `obj_ops_risk_month3`, and `obj_cash_month3`.
- If `obj_audit_month3` passes, `AUDIT_ROOM` unlocks.
- Objective rewards cannot duplicate.
- No backend or LLM call is required.

### Patch 8 Recommendation

Patch 8 should turn `AUDIT_ROOM` into a playable audit response tool with finding remediation, control evidence spending, management representation choices, and consequences tied to accumulated audit score.
