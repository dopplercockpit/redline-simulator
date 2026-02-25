from __future__ import annotations

from datetime import datetime
from typing import Any, List, Optional

from pydantic import BaseModel, Field


class EventIn(BaseModel):
    event_type: str = Field(..., min_length=1)
    payload: dict[str, Any] = Field(default_factory=dict)


class EventOut(BaseModel):
    id: int
    event_type: str
    payload: dict[str, Any]
    created_at: datetime


class EmailGenerateRequest(BaseModel):
    learner_id: Optional[str] = None
    difficulty: Optional[int] = Field(default=1, ge=1, le=5)


class EmailMessage(BaseModel):
    email_id: str
    subject: str
    sender: str
    body: str
    targets: List[str]
    choices: List[str]


class EmailReplyRequest(BaseModel):
    email_id: str
    reply_text: str


class Effects(BaseModel):
    cash_delta: float = 0.0
    audit_delta: float = 0.0
    reputation_delta: float = 0.0
    ops_risk_delta: float = 0.0
    unlock_flags: List[str] = Field(default_factory=list)


class FrenchScore(BaseModel):
    errors: List[str] = Field(default_factory=list)
    corrected_text: str
    explanation_short: str
    sr_items: List[str] = Field(default_factory=list)


class BullshitScore(BaseModel):
    score_0_100: int
    flags: List[str] = Field(default_factory=list)
    explanation_short: str


class EmailReplyResult(BaseModel):
    email_id: str
    french_score: FrenchScore
    bullshit_score: BullshitScore
    effects: Effects
    sr_updates: List[dict[str, Any]] = Field(default_factory=list)


class RgmPricingTestRequest(BaseModel):
    baseline_price: float
    baseline_volume: float
    variant_price: float
    elasticity: float
    capacity: float
    congestion_penalty_pct: float = Field(default=0.2, ge=0.0, le=1.0)


class RgmPricingTestResult(BaseModel):
    volume_variant: float
    revenue_variant: float
    revenue_base: float
    congestion_penalty: float
    risk_flags: List[str] = Field(default_factory=list)


class ContractGenerateRequest(BaseModel):
    learner_id: Optional[str] = None
    scenario: Optional[str] = None


class ContractMessage(BaseModel):
    contract_id: str
    title: str
    body: str
    clauses: List[str]
