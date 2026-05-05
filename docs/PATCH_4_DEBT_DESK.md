# Patch 4 Debt Desk

Debt Desk v1 turns the `DEBT_DESK` unlock into a local financing tool. It is available only after the scenario objective unlocks it.

## What It Does

The player can open the inbox after Month 1 and choose a financing offer. Debt proceeds are posted through the ledger, not directly added to cash.

## Ledger Posting

Debt draws debit `1000 Cash` and credit the selected debt liability account:

- `2300 Short-Term Debt / Revolver`
- `2400 Debt - Term Loan`

The supplemental term loan also posts its financing fee:

- Dr `5300 Professional Fees / Close Prep Expense`
- Cr `1000 Cash`

## Future Interest

Draw offers add a debt item to `GameStateData.debt_stack`. Airport weekly finance already sums each debt stack item as:

`principal * rate_apr / 52`

That means new debt increases future weekly interest expense without adding a separate amortization engine.

## Duplicate Prevention

Patch 4 allows one debt draw in the MVP run. Successful draw offers set:

`LoopState.flags["tool_used.DEBT_DESK"] = true`

Declining debt sets `tool_seen.DEBT_DESK` but does not consume the tool, so the player can reopen the Debt Desk and choose a draw later.
