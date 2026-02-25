from __future__ import annotations

import os
from typing import Any

from .openai_client import OpenAIClient

KEYWORDS = [
    "best-in-class",
    "synergy",
    "ai-powered",
    "guaranteed roi",
    "next-generation",
    "paradigm shift",
    "game-changing",
    "revolutionary",
    "turnkey",
    "world-class",
]


def heuristic_score(text: str) -> tuple[int, list[str], str]:
    lowered = text.lower()
    hits = [kw for kw in KEYWORDS if kw in lowered]
    score = min(100, len(hits) * 12)
    explanation = "No obvious buzzword inflation." if not hits else "Buzzword-heavy phrasing detected."
    return score, hits, explanation


def llm_score(text: str, client: OpenAIClient) -> dict[str, Any]:
    schema = {
        "type": "object",
        "properties": {
            "score_0_100": {"type": "integer", "minimum": 0, "maximum": 100},
            "flags": {"type": "array", "items": {"type": "string"}},
            "explanation_short": {"type": "string"},
        },
        "required": ["score_0_100", "flags", "explanation_short"],
        "additionalProperties": False,
    }

    result = client.responses_json(
        schema=schema,
        system_prompt=(
            "You are a strict grader that detects marketing fluff or unreliable claims. "
            "Return JSON only."
        ),
        user_prompt=f"Score the following reply for bullshit level:\n{text}",
        temperature=0.1,
    )
    return result


def score_text(text: str, use_llm: bool = False) -> dict[str, Any]:
    if use_llm and os.getenv("OPENAI_API_KEY"):
        client = OpenAIClient()
        if client.available:
            return llm_score(text, client)

    score, flags, explanation = heuristic_score(text)
    return {
        "score_0_100": score,
        "flags": flags,
        "explanation_short": explanation,
    }
