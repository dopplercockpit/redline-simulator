from __future__ import annotations

from fastapi import FastAPI

from .db import init_db
from .routers import contract, email, events, rgm

app = FastAPI(title="Unified Academy Backend", version="0.1.0")


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
