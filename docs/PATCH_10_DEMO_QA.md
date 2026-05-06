# Patch 10 - Demo Polish + QA Harness

## Demo / QA Panel

Press `Ctrl+Alt+D` in the CFO Office to open the local Demo / QA panel. This panel is a development and instruction aid. It does not call backend services and does not use LLMs.

## Demo Targets

The panel can apply deterministic fixture states:

- `fresh_start`
- `month1_complete`
- `month2_complete`
- `month3_complete`
- `full_demo_complete`

Demo states are structurally valid save payloads. They are not simulation replays. `DemoHarness` returns payloads only; `GameManager` applies them through the Patch 9 serializer path.

## Smoke Test

`RunValidator` checks that core files exist and parse, action cards cover weeks 1-12, required COA accounts exist, mission/tool JSON files parse, and basic runtime state is available.

## Manual Demo Script

1. Run the main scene.
2. Press `Ctrl+Alt+D`.
3. Run Smoke Test.
4. Jump to Month 1 Complete and open the phone to inspect Debt Desk.
5. Jump to Month 2 Complete and open the contract cabinet.
6. Jump to Month 3 Complete and open the TV Audit Room.
7. Jump to Full Demo Complete and export the summary from the Run Menu.
8. Open Run Menu > Open Run Review to inspect the decision timeline and Markdown preview.

## Known Limitations

Demo fixtures are approximate. They are intended for QA and classroom demonstration, not for balancing exact economics. Normal gameplay remains the authoritative path for player runs.

## Patch 11 Recommendation

Patch 11 should add a polished run review viewer with a decision timeline, save-slot metadata, and a local Markdown preview for exported summaries.
