from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
import json, os
from ..services.llm_client import analyst_feedback

router = APIRouter(prefix="/midterm", tags=["midterm"])

# FIX: point to backend/data/midterm/...
DATA_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "data", "midterm", "scenarios.json")
)

with open(DATA_PATH, "r", encoding="utf-8") as f:
    SCENARIOS = json.load(f)

class CommentaryPayload(BaseModel):
    iteration_id: int = Field(..., ge=1)
    commentary: str = Field(..., min_length=10)

@router.get("/state")
def get_state(iteration_id: int = 1):
    it = next((i for i in SCENARIOS["iterations"] if i["id"] == iteration_id), None)
    if not it:
        raise HTTPException(status_code=404, detail="Iteration not found")
    return {
        "company": SCENARIOS["company"],
        "currency": SCENARIOS["currency"],
        "units": SCENARIOS["units"],
        "iteration": it
    }

@router.post("/analyze")
def analyze_commentary(payload: CommentaryPayload):
    it = next((i for i in SCENARIOS["iterations"] if i["id"] == payload.iteration_id), None)
    if not it:
        raise HTTPException(status_code=404, detail="Iteration not found")

    system_msg = (
        "You are an equity research analyst panel grilling a finance student during an earnings call. "
        "Assess their commentary for correctness, clarity, and depth.\n"
        "Be concise but pointed. Use bullets. Structure your response:\n"
        "1) What they got right, 2) What they missed, 3) Suggested next checks (metrics, ratios, questions). "
        "Use data from the provided iteration. Avoid inventing numbers."
    )

    user_ctx = (
        f"Company: {SCENARIOS['company']} | Units: {SCENARIOS['units']} | Currency: {SCENARIOS['currency']}\n"
        f"Iteration {it['id']} — {it['title']}\n"
        f"Narrative: {it['narrative']}\n"
        f"Income Statement: {it['income_statement']}\n"
        f"Balance Sheet: {it['balance_sheet']}\n"
        f"Cash Flow: {it['cash_flow']}\n\n"
        f"Student commentary:\n{payload.commentary}"
    )

    try:
        text = analyst_feedback(system=system_msg, user=user_ctx)
        return {"analysis": text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
