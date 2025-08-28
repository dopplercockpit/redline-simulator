# backend/api/
from fastapi import APIRouter, Query
from datetime import date
from ..seeds.baseline import load_baseline
from fastapi import Body
from ..services.finance.ledger_store import reset_ledger
from ..services.finance.ledger_store import export_ledger_json, import_ledger_json, ledger_state


router = APIRouter(prefix="/admin", tags=["admin"])

@router.post("/reset")
def api_reset():
    reset_ledger()
    return {"reset": True}

@router.post("/load/baseline")
def api_load_baseline(as_of: date = Query(..., description="Opening balance date")):
    return load_baseline(as_of)

@router.get("/state")
def api_admin_state():
    """Tiny health check for the in-memory ledger."""
    return ledger_state()

@router.get("/export/ledger")
def api_export_ledger():
    """
    Export the entire ledger as JSON.
    Useful for snapshots, tests, and moving scenarios between machines.
    """
    return export_ledger_json()

@router.post("/import/ledger")
def api_import_ledger(payload: dict = Body(..., description="Export payload from /admin/export/ledger")):
    """
    Replace the current in-memory ledger with the provided JSON.
    WARNING: This overwrites current state. Export before you import if you care.
    """
    return import_ledger_json(payload)
