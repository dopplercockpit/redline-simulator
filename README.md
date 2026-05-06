# Redline Simulator: Flightpath CFO

Redline Simulator: Flightpath CFO is a Godot 4.5 educational CFO simulator. Players run a distressed regional airport through cash survival, debt financing, route incentives, contract governance, compliance pressure, and audit remediation.

This is a local MVP/prototype, not a production LMS.

## Current MVP Scope

- Month 1: cash triage, vendor pressure, concessions, close prep.
- Month 2: BudgetAir route incentive economics.
- Month 3: compliance, clawback, covenant pressure, audit posture.
- Unlockable tools: Debt Desk, Contract Review, Audit Room.
- Local save/load/export and demo fixtures.

## How To Run

1. Open the repository in Godot 4.5.
2. Run the main scene.
3. Enter the CFO Office.

## Main Scene

`res://scenes/WorldMap.tscn`

## Demo / QA Shortcut

Press `Ctrl+Alt+D` in the CFO Office to open the Demo / QA panel.

Use it to:
- run the smoke test,
- jump to Month 1/2/3 completion states,
- apply `full_demo_complete`,
- export a summary for review.

## Core Gameplay Loop

1. Open the phone/inbox.
2. Read the weekly action card.
3. Choose one option.
4. Review ledger and financial statement consequences.
5. Advance week.
6. Complete boardroom month close.
7. Unlock tools and review the run.

## Major Systems

- Laptop: Financial Panel.
- Phone: Inbox, weekly action cards, boardroom missions.
- Cabinet: Contract Review after unlock.
- TV: Audit Room after unlock.
- Painting/archive: Run Menu.
- Run Menu: save, load, export, reset, open Run Review.
- Demo / QA: `Ctrl+Alt+D`.

## Save / Load / Export

- Save path: `user://flightpath_run_save.json`
- Export path: `user://flightpath_run_summary.md`
- The ledger is the source of truth.
- Browser exports use browser-managed `user://` storage.

## Instructor Demo

See:
- `res://docs/INSTRUCTOR_DEMO_SCRIPT.md`
- `res://docs/WEB_EXPORT_CHECKLIST.md`
- `res://docs/PATCH_11_RUN_REVIEW.md`

Recommended quick demo:
1. Press `Ctrl+Alt+D`.
2. Run Smoke Test.
3. Apply `full_demo_complete`.
4. Open Run Menu from the painting/archive.
5. Open Run Review.
6. Preview/export Markdown.

## Repository Structure

- `engine/`: core simulation, ledger, persistence, demo/QA helpers.
- `data/`: scenarios, action cards, missions, contracts, tool definitions, COA.
- `scenes/`: Godot scenes and CFO Office script.
- `ui/`: panels and player-facing tools.
- `docs/`: patch notes, canonical product docs, demo docs.

## No Backend Required

The Month 1-3 MVP runs locally. No backend, LLM, login, or instructor dashboard server is required.

## Known Limitations

- Demo fixtures are deterministic approximations, not full simulation replays.
- Save/export paths are local `user://` paths.
- Browser storage can be cleared by site data cleanup.
- The Windows root certificate warning seen in headless local checks is non-fatal.

## Next Steps

- Packaging and export preset cleanup.
- Browser smoke testing.
- Save-slot UX.
- In-game Markdown export viewer polish.
