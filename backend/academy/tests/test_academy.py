import os

os.environ.setdefault("ACADEMY_DB_URL", "sqlite:///./academy_test.db")

from fastapi.testclient import TestClient

from backend.academy.app.main import app


client = TestClient(app)


def test_email_generate_schema():
    response = client.post("/v1/redline/email/generate", json={"difficulty": 1})
    assert response.status_code == 200
    data = response.json()
    assert "email_id" in data
    assert "subject" in data
    assert "sender" in data
    assert "body" in data
    assert isinstance(data.get("targets"), list)
    assert isinstance(data.get("choices"), list)


def test_email_reply_returns_scores_and_effects():
    gen = client.post("/v1/redline/email/generate", json={"difficulty": 1}).json()
    reply = client.post(
        "/v1/redline/email/reply",
        json={"email_id": gen["email_id"], "reply_text": "Il faut que nous limitons le capex."},
    )
    assert reply.status_code == 200
    data = reply.json()
    assert "french_score" in data
    assert "bullshit_score" in data
    assert "effects" in data
    assert "sr_updates" in data


def test_pricing_test_returns_numbers_and_flags():
    response = client.post(
        "/v1/rgm/pricing/test",
        json={
            "baseline_price": 100,
            "baseline_volume": 1000,
            "variant_price": 110,
            "elasticity": -0.4,
            "capacity": 950,
            "congestion_penalty_pct": 0.2,
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data["volume_variant"], (int, float))
    assert isinstance(data["revenue_variant"], (int, float))
    assert isinstance(data["revenue_base"], (int, float))
    assert isinstance(data["congestion_penalty"], (int, float))
    assert isinstance(data["risk_flags"], list)
