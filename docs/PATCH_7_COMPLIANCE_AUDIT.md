# Patch 7 - Compliance, Clawback, and Audit Pressure

## Month 3 Arc

Month 3 extends the continuous Flightpath CFO scenario into weeks 9-12. BudgetAir underperforms after the route incentive agreement, then the player handles clawback recovery, audit cleanup, covenant communication, and board governance prep.

## Contract Review Consequences

Week 9's clawback choice is contract-dependent. `ENFORCE_CLAWBACK` requires `LoopState.memory["contract_reviews"]["BUDGETAIR_INCENTIVE_REVIEW"].clawback_strength` to be `moderate` or `strong`. If the player accepted the weak draft in Patch 6, `DecisionResolver` rejects enforcement and returns the configured unavailable feedback.

## GL 4300 Treatment

Patch 7 adds `4300 Route Incentive Clawback Recovery` as an operating revenue account. Successful clawback enforcement posts:

- Dr `1000 Cash` for `$35,000`
- Cr `4300 Route Incentive Clawback Recovery` for `$35,000`

The ledger statement builder maps GL `4300` to `route_incentive_clawback_recovery` and includes it in total operating revenue.

## Objectives

Month 3 evaluates after week 12 boardroom completion:

- `obj_audit_month3`: audit score must stay at or below `18`; rewards `150` points and unlocks `AUDIT_ROOM`.
- `obj_ops_risk_month3`: ops risk must stay at or below `8`; rewards `100` points.
- `obj_cash_month3`: cash must stay at or above `$650,000`; rewards `100` points.

## Boardroom Mission

Month 3 uses `MISSION_MONTH_CLOSE_COMPLIANCE_V1_M3`, loaded from `res://data/missions/month_close_compliance_v1.json`. The mission covers enforceable clawbacks, weak contract risk, compliance preparation, and debt-funded growth covenant pressure.

## Choice Requirements

Action cards may define a `requires` block. Patch 7 supports contract review requirements with `in` or `equals` checks. Requirements are enforced in `DecisionResolver`, so UI panels can remain simple and business rules stay in the simulation layer.
