# Patch 5 Route Incentive

Patch 5 extends the Airport CFO MVP into Month 2 without introducing scenario switching. The same scenario file now contains a second month arc focused on BudgetAir route incentives.

## Month 2 Decision Arc

Weeks 5-8 add four local action cards:

- `CARD_W5_BUDGETAIR_OFFER`
- `CARD_W6_ROUTE_ECONOMICS`
- `CARD_W7_SERVICE_CAPACITY`
- `CARD_W8_BOARD_PREP_ROUTE_INCENTIVE`

The player weighs traffic growth against incentive expense, liquidity, service capacity, audit posture, and board explanation.

## Route Incentive Accounting

Route incentive costs post to `5200 Route Incentive Expense`. Tracking and board-prep support post to `5300 Professional Fees / Close Prep Expense`. Staffing support posts to `5000 Payroll Expense`.

Commercial deltas improve landing fee economics and concessions baseline sales, but the ledger still records the cash cost of the incentive.

## Objective Evaluation

Month 2 adds:

- `obj_route_incentive`: operating margin must stay at or above 5% by week 8.
- `obj_cash_month2`: cash must stay at or above $750,000 by week 8.

Rewards are applied through `GameManager.evaluate_objectives()` after month-close mission completion and cannot be duplicated.

## Boardroom Mission Selection

`MissionManager.enqueue_month_close()` now selects the mission definition by closed month:

- Month 1: `MISSION_MONTH_CLOSE_V1`
- Month 2: `MISSION_MONTH_CLOSE_ROUTE_INCENTIVE_V1`
- Later months: generic month-close fallback
