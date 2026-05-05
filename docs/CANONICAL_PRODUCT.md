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

## Future Layers

LLM and backend services are optional future layers. They are not required for the v0.1 Godot MVP and should not drive core simulation state.

## Legacy/Future Skins

Airline and manufacturing concepts are legacy or future skins. They may remain as backwards-compatible code paths, but Airport CFO / Flightpath is the active canonical direction.
