# Web Export Notes (Minimum Plumbing)

## API base URL source order
1. `window.REDLINE_CONFIG.API_BASE_URL` from the web shell at runtime.
2. `application/config/backend_base_url` in `project.godot`.
3. `http://127.0.0.1:8000` fallback in `BackendClient.gd`.

## Where to set the web API URL
- Edit `web/custom_shell.html` and set:
  - `window.REDLINE_CONFIG = { API_BASE_URL: "https://api.your-domain.com" };`
- Or inject the same object in hosting before the Godot runtime script executes.
- Hosted fallback when not injected:
  - the shell defaults to `window.location.origin` (same-origin API assumption).
  - set `API_BASE_URL` explicitly for split frontend/backend staging deployments.

## Local web test quick path
- Keep local backend on `http://127.0.0.1:8000`.
- Keep shell fallback logic as-is (`localhost` hostnames resolve to local backend).

## Export preset
- `export_presets.cfg` now points Web export to:
  - `html/custom_html_shell="res://web/custom_shell.html"`

## Backend CORS staging note
- Academy backend CORS origins are controlled by:
  - `ACADEMY_CORS_ORIGINS` (preferred), or
  - `CORS_ORIGINS` (fallback).
- Use comma-separated origins, for example:
  - `https://staging.redline-sim.com,https://preview.redline-sim.com`
