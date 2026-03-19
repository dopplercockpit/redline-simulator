# Unified Academy Backend (v0)

## Run

```powershell
python -m uvicorn backend.academy.app.main:app --reload
```

## Environment

- `OPENAI_API_KEY`: optional. If set, email generation and French scoring use OpenAI Responses API.
- `OPENAI_MODEL`: optional (default: `gpt-4.1-mini`).
- `ACADEMY_DB_URL`: optional (default: `sqlite:///backend/academy/academy.db`).
- `ACADEMY_CORS_ORIGINS`: optional comma-separated origins for frontend access (preferred).
- `CORS_ORIGINS`: optional fallback env name for origin list.

## Example requests

Generate an email:

```powershell
curl -X POST http://127.0.0.1:8000/v1/redline/email/generate -H "Content-Type: application/json" -d "{\"difficulty\":1}"
```

Reply to an email:

```powershell
curl -X POST http://127.0.0.1:8000/v1/redline/email/reply -H "Content-Type: application/json" -d "{\"email_id\":\"<email_id>\",\"reply_text\":\"Il faut que nous limitons le capex.\"}"
```

Pricing test:

```powershell
curl -X POST http://127.0.0.1:8000/v1/rgm/pricing/test -H "Content-Type: application/json" -d "{\"baseline_price\":100,\"baseline_volume\":1000,\"variant_price\":110,\"elasticity\":-0.4,\"capacity\":950,\"congestion_penalty_pct\":0.2}"
```

Run with explicit staging-like CORS origins:

```powershell
$env:ACADEMY_CORS_ORIGINS="https://staging.redline-sim.com,https://preview.redline-sim.com"
python -m uvicorn backend.academy.app.main:app --reload
```

Render helper:
- `backend/academy/render.staging.yaml` targets `backend.academy.app.main:app` for hosted staging.
