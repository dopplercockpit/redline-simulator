# Patch 6 - Contract Review v1

## Purpose

Contract Review turns the Month 2 `CONTRACT_REVIEW` unlock into a local governance tool. The player reviews the BudgetAir route incentive agreement and chooses how much control discipline to add before signing.

## BudgetAir Agreement

The active contract template is `res://data/contracts/flightpath/budgetair_route_incentive_v1.txt`. The review definition in `res://data/tools/contract_review/contract_reviews_v1.json` supplies the BudgetAir variables, body copy, and handling choices.

## Choice Effects

Every choice routes through `DecisionResolver` as `contract_review_choice`.

- `ACCEPT_AS_IS` posts no ledger transaction, stores a high-risk contract result, and increases audit and operating risk.
- `ADD_CLAWBACK_AND_SERVICE_COMMITMENT` posts professional fee expense, stores a low-risk result, and reduces audit and operating risk.
- `ADD_CLAWBACK_ONLY` posts a smaller professional fee expense and stores a medium-risk result.
- `ESCALATE_TO_BOARD` posts no ledger transaction and stores an escalated governance result.

## Ledger Treatment

Review costs are posted through the ledger, not direct cash mutation. The review-cost options debit `5300 Professional Fees / Close Prep Expense` and credit `1000 Cash`. Financial statements are regenerated from the ledger after the resolver applies the choice.

## Contract State

Applied reviews are upserted into `_financial_state.contracts["active"]` and mirrored into `LoopState.memory["contract_reviews"]` for UI display. This lets the contract cabinet show completed status and lets scorecards include the selected contract risk result.

## Duplicate Prevention

Patch 6 allows one execution per review. The resolver sets `LoopState.flags["contract_review_completed.<REVIEW_ID>"] = true` after a successful choice and rejects later attempts for the same review id.
