from __future__ import annotations

from datetime import datetime, timedelta


def schedule_item(skill_tag: str, difficulty: int, due_days: int) -> dict:
    due_date = datetime.utcnow() + timedelta(days=due_days)
    return {
        "skill_tag": skill_tag,
        "difficulty": difficulty,
        "due_date": due_date.isoformat() + "Z",
        "interval_days": due_days,
    }
