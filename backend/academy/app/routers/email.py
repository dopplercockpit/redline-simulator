from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..db import ContentCache, get_db
from ..schemas import EmailGenerateRequest, EmailMessage, EmailReplyRequest, EmailReplyResult, Effects, FrenchScore
from ..services.bullshit_detector import score_text
from ..services.openai_client import OpenAIClient
from ..services.scheduler import schedule_item

router = APIRouter()

FRENCH_TARGETS = [
    "il faut que",
    "ce dont",
    "bien que",
]

DEFAULT_EMAIL = {
    "subject": "Budget Q3: Risk of terminal congestion",
    "sender": "Claire Martin, CFO",
    "body": (
        "Bonjour,\n\nNous devons finaliser le budget Q3. Il faut que vous proposiez une option "
        "qui limite les disruptions operations, bien que le trafic soit en hausse. "
        "Merci d'indiquer ce dont vous avez besoin pour respecter un capex <= 2M.\n\n"
        "Cordialement,\nClaire"
    ),
    "targets": ["il faut que", "bien que"],
    "choices": [
        "Option A: Prioritize maintenance overtime, capex 1.8M.",
        "Option B: Add gates and staffing, capex 2.4M.",
        "Option C: Defer upgrades, focus on cash savings.",
    ],
    "constraints": ["capex <= 2M", "limit disruptions"],
}


def _email_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "subject": {"type": "string"},
            "sender": {"type": "string"},
            "body": {"type": "string"},
            "targets": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 2},
            "choices": {"type": "array", "items": {"type": "string"}, "minItems": 2, "maxItems": 3},
            "constraints": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 3},
        },
        "required": ["subject", "sender", "body", "targets", "choices", "constraints"],
        "additionalProperties": False,
    }


def _french_score_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "errors": {"type": "array", "items": {"type": "string"}},
            "corrected_text": {"type": "string"},
            "explanation_short": {"type": "string"},
            "sr_items": {"type": "array", "items": {"type": "string"}},
        },
        "required": ["errors", "corrected_text", "explanation_short", "sr_items"],
        "additionalProperties": False,
    }


def _heuristic_french_score(reply_text: str, targets: list[str]) -> FrenchScore:
    lowered = reply_text.lower()
    matched = [target for target in targets if target.lower() in lowered]
    errors = [] if matched else ["Missing required French target phrase."]
    explanation = "Targets detected." if matched else "No target phrase detected."
    return FrenchScore(
        errors=errors,
        corrected_text=reply_text,
        explanation_short=explanation,
        sr_items=matched,
    )


def _compute_effects(reply_text: str, targets: list[str], constraints: list[str], bullshit_score: int) -> Effects:
    lowered = reply_text.lower()
    effects = Effects()

    if any(target.lower() in lowered for target in targets):
        effects.reputation_delta += 2.0

    if bullshit_score <= 30:
        effects.audit_delta += 1.5

    constraint_hits = 0
    if any("capex" in c.lower() or "2m" in c.lower() for c in constraints):
        if "capex" in lowered or "2m" in lowered or "2 m" in lowered or "budget" in lowered:
            constraint_hits += 1
    if any("disruption" in c.lower() for c in constraints):
        if "disruption" in lowered or "ops" in lowered or "operations" in lowered:
            constraint_hits += 1

    if constraint_hits == 0:
        effects.cash_delta -= 1.0
        effects.ops_risk_delta += 1.0
    elif constraint_hits == 1:
        effects.ops_risk_delta += 0.5

    return effects


@router.post("/generate", response_model=EmailMessage)
def generate_email(request: EmailGenerateRequest, db: Session = Depends(get_db)) -> EmailMessage:
    client = OpenAIClient()
    payload = DEFAULT_EMAIL

    if client.available:
        payload = client.responses_json(
            schema=_email_schema(),
            system_prompt=(
                "You generate CFO email scenarios for an airport business game. "
                "Include 1-2 French target phrases and 2-3 decision choices."
            ),
            user_prompt=(
                "Generate a scenario email. Ensure targets are in French and choices are clear."
            ),
            temperature=0.4,
        )

    email_id = str(uuid.uuid4())
    message = EmailMessage(
        email_id=email_id,
        subject=payload["subject"],
        sender=payload["sender"],
        body=payload["body"],
        targets=payload["targets"],
        choices=payload["choices"],
    )

    db.add(ContentCache(content_type="email", content_json={"email_id": email_id, **payload}))
    db.commit()

    return message


@router.post("/reply", response_model=EmailReplyResult)
def reply_email(request: EmailReplyRequest, db: Session = Depends(get_db)) -> EmailReplyResult:
    cached = db.query(ContentCache).filter(ContentCache.content_type == "email").all()
    payload = None
    for row in cached:
        if row.content_json.get("email_id") == request.email_id:
            payload = row.content_json
            break

    if not payload:
        raise HTTPException(status_code=404, detail="email_id not found")

    targets = payload.get("targets", [])
    constraints = payload.get("constraints", [])

    client = OpenAIClient()
    if client.available:
        french_result = client.responses_json(
            schema=_french_score_schema(),
            system_prompt=(
                "You are a strict French writing coach. Return JSON only with errors, corrected_text, "
                "explanation_short, and sr_items."
            ),
            user_prompt=(
                "Grade this French reply. Identify grammar issues, and list any target phrases used.\n"
                f"Targets: {targets}\nReply:\n{request.reply_text}"
            ),
            temperature=0.2,
        )
        french_score = FrenchScore(**french_result)
    else:
        french_score = _heuristic_french_score(request.reply_text, targets)

    bullshit = score_text(request.reply_text)

    effects = _compute_effects(request.reply_text, targets, constraints, bullshit["score_0_100"])

    sr_updates = []
    if french_score.sr_items:
        for item in french_score.sr_items[:2]:
            sr_updates.append(schedule_item(item, difficulty=2, due_days=3))
    else:
        sr_updates.append(schedule_item("email_reply_basics", difficulty=1, due_days=2))

    return EmailReplyResult(
        email_id=request.email_id,
        french_score=french_score,
        bullshit_score=bullshit,
        effects=effects,
        sr_updates=sr_updates,
    )
