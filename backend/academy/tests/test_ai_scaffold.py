import os

os.environ.setdefault("ACADEMY_DB_URL", "sqlite:///./academy_test.db")

from fastapi.testclient import TestClient

from backend.academy.app.main import app


client = TestClient(app)


def _base_envelope(payload: dict) -> dict:
    return {
        "request_id": "req-001",
        "schema_version": "1.0",
        "client": {
            "platform": "web",
            "build_version": "0.1.0",
            "environment": "test",
        },
        "scenario": {
            "scenario_id": "flightpath_001",
            "scenario_version": "1.0.0",
            "domain_module": "flightpath",
        },
        "run_context": {
            "run_id": "run-001",
            "turn_index": 4,
            "week": 4,
            "month": 1,
            "quarter": 1,
            "year": 1,
            "seed": 12345,
        },
        "payload": payload,
    }


def test_gen_news_scaffold_returns_schema_envelope():
    payload = {
        "news_type": "weekly_wrap",
        "tone": "professional",
        "audience": "internal_exec",
        "recent_events": [
            {
                "event_id": "fuel_spike_01",
                "event_type": "cost_shock",
                "headline_hint": "Fuel prices rose sharply",
                "severity": "high",
            }
        ],
        "kpis": {
            "revenue": 1250000,
            "expense": 980000,
            "cash": 540000,
            "margin_pct": 21.6,
            "audit_score": 78,
        },
        "constraints": {"max_items": 2, "max_words_per_item": 90},
    }
    response = client.post("/v1/gen/news", json=_base_envelope(payload))
    assert response.status_code == 200
    data = response.json()
    assert data["request_id"] == "req-001"
    assert data["schema_version"] == "1.0"
    assert data["status"] == "fallback"
    assert data["fallback_used"] is True
    assert data["provider"]["name"] == "stub"
    assert isinstance(data["result"]["items"], list)
    assert len(data["result"]["items"]) >= 1


def test_gen_inbox_scaffold_returns_schema_envelope():
    payload = {
        "message_type": "executive_email",
        "sender_role": "cfo",
        "recipient_role": "player",
        "objective": "highlight liquidity concern",
        "facts": {
            "cash": 240000,
            "cash_change_pct": -18.5,
            "month": 2,
            "audit_score": 62,
        },
        "constraints": {"max_words": 140, "urgency": "medium"},
    }
    response = client.post("/v1/gen/inbox", json=_base_envelope(payload))
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "fallback"
    assert data["fallback_used"] is True
    assert "message" in data["result"]
    assert isinstance(data["result"]["message"]["body"], str)


def test_coach_nudge_scaffold_returns_schema_envelope():
    payload = {
        "player_context": {"experience_level": "student", "hint_level": "moderate"},
        "situation": {
            "screen": "financial_panel",
            "problem_hint": "margin deterioration",
            "recent_actions": ["approve_discount", "delay_maintenance"],
        },
        "metrics": {"margin_pct": 8.4, "expense_growth_pct": 14.2, "audit_score": 55},
        "constraints": {"max_words": 80, "tone": "supportive"},
    }
    response = client.post("/v1/coach/nudge", json=_base_envelope(payload))
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "fallback"
    assert data["fallback_used"] is True
    assert "nudge" in data["result"]
    assert isinstance(data["result"]["nudge"]["body"], str)


def test_bad_payload_returns_validation_error():
    bad_request = _base_envelope(payload={})
    response = client.post("/v1/gen/news", json=bad_request)
    assert response.status_code == 422
