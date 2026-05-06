# Web Export Checklist

## Project

- Godot version: 4.5
- Main scene: `res://scenes/WorldMap.tscn`
- Backend required: No
- LLM required: No

## Local Save Notes

- Full-run save path: `user://flightpath_run_save.json`
- Export summary path: `user://flightpath_run_summary.md`
- In browser exports, `user://` maps to browser-managed storage rather than a normal filesystem folder.

## Browser / HTML5 Notes

- Browser storage can be cleared by site data cleanup.
- Export summary is written inside the browser sandbox.
- For classroom delivery, test save/load/export in the target browser before the session.

## Demo Shortcut

- `Ctrl+Alt+D` opens Demo / QA.
- Run Smoke Test before a demo.
- Use `full_demo_complete` to inspect all unlocked systems quickly.

## Known Warning

- The Windows root certificate warning observed in local headless checks is non-fatal for the local MVP.

## Final Manual Test Checklist

- Run main scene.
- Open CFO Office.
- Open laptop financials.
- Open phone action card.
- Press `Ctrl+Alt+D`.
- Run Smoke Test.
- Apply `full_demo_complete`.
- Open Run Menu from painting/archive.
- Open Run Review.
- Preview Markdown.
- Export Summary.
- Reset Run.
