from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db import init_db
from .routers import coach, contract, email, events, gen, rgm


def _resolve_cors_origins() -> list[str]:
    raw_origins = os.getenv("ACADEMY_CORS_ORIGINS") or os.getenv("CORS_ORIGINS", "")
    parsed = [origin.strip() for origin in raw_origins.split(",") if origin.strip()]
    if parsed:
        return parsed

    # Local-first defaults; set ACADEMY_CORS_ORIGINS for hosted staging/prod origins.
    return [
        "http://127.0.0.1:5173",
        "http://localhost:5173",
        "http://127.0.0.1:3000",
        "http://localhost:3000",
        "http://127.0.0.1:8000",
        "http://localhost:8000",
    ]


_CORS_ORIGINS = _resolve_cors_origins()
_ALLOW_ALL_ORIGINS = "*" in _CORS_ORIGINS

app = FastAPI(title="Unified Academy Backend", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if _ALLOW_ALL_ORIGINS else _CORS_ORIGINS,
    allow_credentials=not _ALLOW_ALL_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    init_db()


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


app.include_router(events.router, prefix="/v1/events", tags=["events"])
app.include_router(email.router, prefix="/v1/redline/email", tags=["redline-email"])
app.include_router(contract.router, prefix="/v1/redline/contract", tags=["redline-contract"])
app.include_router(rgm.router, prefix="/v1/rgm/pricing", tags=["rgm-pricing"])
app.include_router(gen.router, prefix="/v1/gen", tags=["gen"])
app.include_router(coach.router, prefix="/v1/coach", tags=["coach"])
