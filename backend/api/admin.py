# backend/api/
from fastapi import APIRouter, Query
from datetime import date
from ..seeds.baseline import load_baseline
from ..services.finance.ledger_store import reset_ledger

router = APIRouter(prefix="/admin", tags=["admin"])

@router.post("/reset")
def api_reset():
    reset_ledger()
    return {"reset": True}

@router.post("/load/baseline")
def api_load_baseline(as_of: date = Query(..., description="Opening balance date")):
    return load_baseline(as_of)
