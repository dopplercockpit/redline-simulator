from __future__ import annotations

from fastapi import APIRouter

from ..schemas_ai import AIProviderMeta, CoachNudgeRequest, CoachNudgeResponse
from ..services.ai_stub_service import generate_nudge

router = APIRouter()

STUB_PROVIDER = AIProviderMeta(name="stub", model="deterministic-v1")


@router.post("/nudge", response_model=CoachNudgeResponse)
def post_nudge(request: CoachNudgeRequest) -> CoachNudgeResponse:
    result = generate_nudge(request.payload)
    return CoachNudgeResponse(
        request_id=request.request_id,
        schema_version=request.schema_version,
        status="fallback",
        fallback_used=True,
        provider=STUB_PROVIDER,
        result=result,
        warnings=["stub_provider"],
        errors=[],
    )
