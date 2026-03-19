from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class AIClientMeta(BaseModel):
    model_config = ConfigDict(extra="forbid")

    platform: str = Field(..., min_length=1)
    build_version: str = Field(..., min_length=1)
    environment: str = Field(..., min_length=1)


class AIScenarioMeta(BaseModel):
    model_config = ConfigDict(extra="forbid")

    scenario_id: str = Field(..., min_length=1)
    scenario_version: str = Field(..., min_length=1)
    domain_module: str = Field(..., min_length=1)


class AIRunContext(BaseModel):
    model_config = ConfigDict(extra="forbid")

    run_id: str = Field(..., min_length=1)
    turn_index: int = Field(..., ge=0)
    week: int = Field(..., ge=1)
    month: int = Field(..., ge=1)
    quarter: int = Field(..., ge=1)
    year: int = Field(..., ge=1)
    seed: int


class AIProviderMeta(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(..., min_length=1)
    model: str = Field(..., min_length=1)


class AIRequestEnvelopeBase(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str = Field(..., min_length=1)
    schema_version: str = Field(..., min_length=1)
    client: AIClientMeta
    scenario: AIScenarioMeta
    run_context: AIRunContext


class AIResponseEnvelopeBase(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: str
    schema_version: str
    status: Literal["ok", "fallback", "error"]
    fallback_used: bool
    provider: AIProviderMeta
    warnings: list[str] = Field(default_factory=list)
    errors: list[str] = Field(default_factory=list)


class NewsEvent(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_id: str = Field(..., min_length=1)
    event_type: str = Field(..., min_length=1)
    headline_hint: str = Field(..., min_length=1)
    severity: Literal["low", "medium", "high"]


class NewsKPIs(BaseModel):
    model_config = ConfigDict(extra="forbid")

    revenue: float
    expense: float
    cash: float
    margin_pct: float
    audit_score: float


class NewsConstraints(BaseModel):
    model_config = ConfigDict(extra="forbid")

    max_items: int = Field(default=2, ge=1, le=3)
    max_words_per_item: int = Field(default=90, ge=30, le=200)


class NewsPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    news_type: str = Field(..., min_length=1)
    tone: str = Field(..., min_length=1)
    audience: str = Field(..., min_length=1)
    recent_events: list[NewsEvent] = Field(..., min_length=1, max_length=5)
    kpis: NewsKPIs
    constraints: NewsConstraints


class NewsItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    headline: str
    body: str
    tone: str
    tags: list[str] = Field(default_factory=list)


class NewsResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[NewsItem] = Field(..., min_length=1, max_length=3)


class GenNewsRequest(AIRequestEnvelopeBase):
    payload: NewsPayload


class GenNewsResponse(AIResponseEnvelopeBase):
    result: NewsResult


class InboxFacts(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cash: float | None = None
    cash_change_pct: float | None = None
    month: int | None = Field(default=None, ge=1)
    audit_score: float | None = None


class InboxConstraints(BaseModel):
    model_config = ConfigDict(extra="forbid")

    max_words: int = Field(default=140, ge=40, le=250)
    urgency: Literal["low", "medium", "high"] = "medium"


class InboxPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message_type: str = Field(..., min_length=1)
    sender_role: str = Field(..., min_length=1)
    recipient_role: str = Field(..., min_length=1)
    objective: str = Field(..., min_length=1)
    facts: InboxFacts
    constraints: InboxConstraints


class InboxMessage(BaseModel):
    model_config = ConfigDict(extra="forbid")

    subject: str
    from_label: str
    body: str
    priority: Literal["low", "medium", "high"]
    tags: list[str] = Field(default_factory=list)


class InboxResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message: InboxMessage


class GenInboxRequest(AIRequestEnvelopeBase):
    payload: InboxPayload


class GenInboxResponse(AIResponseEnvelopeBase):
    result: InboxResult


class NudgePlayerContext(BaseModel):
    model_config = ConfigDict(extra="forbid")

    experience_level: str = Field(..., min_length=1)
    hint_level: str = Field(..., min_length=1)


class NudgeSituation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    screen: str = Field(..., min_length=1)
    problem_hint: str = Field(..., min_length=1)
    recent_actions: list[str] = Field(default_factory=list, max_length=6)


class NudgeMetrics(BaseModel):
    model_config = ConfigDict(extra="forbid")

    margin_pct: float | None = None
    expense_growth_pct: float | None = None
    audit_score: float | None = None


class NudgeConstraints(BaseModel):
    model_config = ConfigDict(extra="forbid")

    max_words: int = Field(default=80, ge=30, le=160)
    tone: str = Field(..., min_length=1)


class NudgePayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    player_context: NudgePlayerContext
    situation: NudgeSituation
    metrics: NudgeMetrics
    constraints: NudgeConstraints


class NudgeMessage(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str
    body: str
    hint_level: str
    concept_tags: list[str] = Field(default_factory=list)


class NudgeResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    nudge: NudgeMessage


class CoachNudgeRequest(AIRequestEnvelopeBase):
    payload: NudgePayload


class CoachNudgeResponse(AIResponseEnvelopeBase):
    result: NudgeResult
