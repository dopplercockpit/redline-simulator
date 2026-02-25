# Unified Academy Backend (v0)

## Run

```powershell
python -m uvicorn backend.academy.app.main:app --reload
```

## Environment

- `OPENAI_API_KEY`: optional. If set, email generation and French scoring use OpenAI Responses API.
- `OPENAI_MODEL`: optional (default: `gpt-4.1-mini`).
- `ACADEMY_DB_URL`: optional (default: `sqlite:///backend/academy/academy.db`).

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
