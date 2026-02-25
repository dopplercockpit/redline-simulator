from __future__ import annotations

from typing import Dict


def resolve_location(text: str) -> Dict[str, str | float]:
    if not text:
        return {"city": "", "country": "", "confidence": 0.0}

    lowered = text.lower()
    if "paris" in lowered:
        return {"city": "Paris", "country": "France", "confidence": 0.8}
    if "london" in lowered:
        return {"city": "London", "country": "United Kingdom", "confidence": 0.8}

    return {"city": "", "country": "", "confidence": 0.2}
