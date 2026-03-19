from __future__ import annotations

from fastapi import APIRouter

from ..schemas_ai import AIProviderMeta, GenInboxRequest, GenInboxResponse, GenNewsRequest, GenNewsResponse
from ..services.ai_stub_service import generate_inbox, generate_news

router = APIRouter()

STUB_PROVIDER = AIProviderMeta(name="stub", model="deterministic-v1")


@router.post("/news", response_model=GenNewsResponse)
def post_news(request: GenNewsRequest) -> GenNewsResponse:
    # Stub-first behavior keeps endpoints render-safe while real provider integration is added later.
    result = generate_news(request.payload)
    return GenNewsResponse(
        request_id=request.request_id,
        schema_version=request.schema_version,
        status="fallback",
        fallback_used=True,
        provider=STUB_PROVIDER,
        result=result,
        warnings=["stub_provider"],
        errors=[],
    )


@router.post("/inbox", response_model=GenInboxResponse)
def post_inbox(request: GenInboxRequest) -> GenInboxResponse:
    result = generate_inbox(request.payload)
    return GenInboxResponse(
        request_id=request.request_id,
        schema_version=request.schema_version,
        status="fallback",
        fallback_used=True,
        provider=STUB_PROVIDER,
        result=result,
        warnings=["stub_provider"],
        errors=[],
    )
