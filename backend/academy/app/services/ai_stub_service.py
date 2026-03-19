from __future__ import annotations

from ..schemas_ai import (
    InboxMessage,
    InboxPayload,
    InboxResult,
    NewsItem,
    NewsPayload,
    NewsResult,
    NudgeMessage,
    NudgePayload,
    NudgeResult,
)


def _truncate_words(text: str, max_words: int) -> str:
    words = text.split()
    if len(words) <= max_words:
        return text
    return " ".join(words[:max_words]).rstrip(",.;:") + "."


def generate_news(payload: NewsPayload) -> NewsResult:
    items: list[NewsItem] = []
    max_items = min(payload.constraints.max_items, len(payload.recent_events), 2)

    kpi_line = (
        f"Revenue {payload.kpis.revenue:.0f}, expense {payload.kpis.expense:.0f}, "
        f"cash {payload.kpis.cash:.0f}, margin {payload.kpis.margin_pct:.1f}%."
    )

    for index, event in enumerate(payload.recent_events[:max_items], start=1):
        headline = event.headline_hint.strip()
        body = (
            f"{event.event_type.replace('_', ' ').capitalize()} event ({event.severity} severity) "
            f"was recorded this turn. {kpi_line}"
        )
        body = _truncate_words(body, payload.constraints.max_words_per_item)
        items.append(
            NewsItem(
                id=f"news_{index:03d}",
                headline=headline,
                body=body,
                tone=payload.tone,
                tags=[event.event_type, "kpi_snapshot"],
            )
        )

    return NewsResult(items=items)


def generate_inbox(payload: InboxPayload) -> InboxResult:
    facts: list[str] = []
    if payload.facts.cash is not None:
        facts.append(f"cash={payload.facts.cash:.0f}")
    if payload.facts.cash_change_pct is not None:
        facts.append(f"cash_change_pct={payload.facts.cash_change_pct:.1f}")
    if payload.facts.month is not None:
        facts.append(f"month={payload.facts.month}")
    if payload.facts.audit_score is not None:
        facts.append(f"audit_score={payload.facts.audit_score:.0f}")

    facts_text = ", ".join(facts) if facts else "no additional numeric facts supplied"
    subject = payload.objective.strip().capitalize()
    from_label = f"{payload.sender_role.upper()} Office"
    body = (
        f"Focus: {payload.objective}. Current context: {facts_text}. "
        "Prioritize a near-term review and align options before committing."
    )
    body = _truncate_words(body, payload.constraints.max_words)

    message = InboxMessage(
        subject=subject,
        from_label=from_label,
        body=body,
        priority=payload.constraints.urgency,
        tags=["inbox", payload.sender_role, payload.message_type],
    )
    return InboxResult(message=message)


def generate_nudge(payload: NudgePayload) -> NudgeResult:
    action_text = ""
    if payload.situation.recent_actions:
        action_text = f" Review your last move ({payload.situation.recent_actions[0]})."

    metric_text = ""
    if payload.metrics.margin_pct is not None:
        metric_text = f" Margin is currently {payload.metrics.margin_pct:.1f}%."
    elif payload.metrics.expense_growth_pct is not None:
        metric_text = f" Expense growth is {payload.metrics.expense_growth_pct:.1f}%."

    body = (
        f"Start with the driver behind {payload.situation.problem_hint} and compare trend direction."
        f"{action_text}{metric_text} Focus on diagnosis first, then choose the next lever."
    )
    body = _truncate_words(body, payload.constraints.max_words)

    nudge = NudgeMessage(
        title=f"Check: {payload.situation.problem_hint}",
        body=body,
        hint_level=payload.player_context.hint_level,
        concept_tags=["diagnosis", "tradeoff", "financial_review"],
    )
    return NudgeResult(nudge=nudge)
