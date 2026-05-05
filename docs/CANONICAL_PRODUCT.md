# Redline Simulator: Flightpath CFO

## Canonical v0.1 Module

The canonical v0.1 product is Airport CFO. The player runs a distressed regional airport and learns CFO judgment through weekly decisions, ledger postings, financial statements, month-end close, boardroom questions, points/unlocks, and audit pressure.

## Main Loop

1. Week begins.
2. Player reviews airport financial and operating context.
3. Player makes a decision.
4. The decision and weekly operations post to the ledger.
5. Statements are generated from the ledger.
6. Month close runs after week 4.
7. Boardroom quiz tests the close story.
8. Points, unlocks, and audit pressure update the run.

## Source of Truth

The ledger is the source of truth. Airport CFO statements are generated from GL balances in `res://data/finance/coa_airport_v1.json`, seeded and advanced by `res://data/scenarios/flightpath/scenario_001.json`.

## Patch 2 Action Card Rule

Weekly decisions are local, JSON-driven action cards. The inbox is the player-facing action hub. Choices may post ledger transactions and update airport/economy/loop state, but all mutations must go through `DecisionResolver`.

## Patch 3 Progression Rule

Scenario objectives are evaluated after month-close mission completion. Rewards may award points and unlock tools. The player must see consequences through `StatusHUD` and `MonthScorecard`.

## Patch 4 Financing Tool Rule

Unlocked tools become playable local systems. Debt Desk v1 posts financing transactions to the ledger and adds debt_stack items that increase future interest expense. Debt is a liquidity lever, not free money.

## Patch 5 Scenario Continuation Rule

The MVP now supports a continuous multi-month scenario arc. Month 2 introduces route incentive decisions, evaluates operating margin and liquidity, and adds a route-incentive boardroom mission.

## Patch 6 Contract Governance Rule

Contract Review turns unlocked tools into governance mechanics. Contract choices can post review costs, modify contract risk state, affect audit/reputation/ops risk, and must remain ledger-first.

## Patch 7 Compliance and Contract Consequence Rule

Contract terms must affect later gameplay. Month 3 converts the BudgetAir agreement into clawback, compliance, audit, covenant, and board-pressure decisions. The resolver enforces contract-dependent choices.

## Future Layers

LLM and backend services are optional future layers. They are not required for the v0.1 Godot MVP and should not drive core simulation state.

## Legacy/Future Skins

Airline and manufacturing concepts are legacy or future skins. They may remain as backwards-compatible code paths, but Airport CFO / Flightpath is the active canonical direction.
