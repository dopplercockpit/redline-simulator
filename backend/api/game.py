# =====================================================
# SECTION 2: BACKEND - GAME API ROUTES
# File: backend/api/game.py
# =====================================================

"""
backend/api/game.py
Game API endpoints for Redline Simulator
"""

from fastapi import APIRouter, HTTPException, Query, Body
from typing import Dict, Optional, List
from datetime import date
from pydantic import BaseModel, Field
from backend.services.finance.statements import StatementGenerator
from backend.services.game_state import GameState, PlayerDecision, GameManager

router = APIRouter(prefix="/game", tags=["game"])

# Initialize game manager (you'll need to implement this)
game_manager = GameManager()

class NewGameRequest(BaseModel):
    player_name: str = Field(..., description="Player/student name")
    scenario_id: str = Field(..., description="Scenario to play")
    seed: Optional[int] = Field(None, description="Random seed")

class TickRequest(BaseModel):
    days: int = Field(1, ge=1, le=30, description="Days to advance")

class DecisionRequest(BaseModel):
    decision_type: str
    parameters: Dict
    narrative: Optional[str] = None

@router.post("/new")
def new_game(request: NewGameRequest):
    import uuid
    session_id = str(uuid.uuid4())
    
    try:
        state = game_manager.new_game(
            session_id=session_id,
            scenario_id=request.scenario_id,
            seed=request.seed
        )
        return {
            "session_id": session_id,
            "scenario_id": state.scenario_id,
            "current_date": str(state.current_date),
            "week_number": state.week_number,
            "month_number": state.month_number,
            "cash": state.cash,
            "kpis": state.kpis
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{session_id}/tick")
def advance_time(session_id: str, request: TickRequest):
    try:
        state = game_manager.tick(session_id, request.days)
        return {
            "session_id": session_id,
            "current_date": str(state.current_date),
            "week_number": state.week_number,
            "cash": state.cash,
            "revenue_mtd": state.revenue_mtd,
            "costs_mtd": state.costs_mtd,
            "kpis": state.kpis
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.post("/{session_id}/decision")
def make_decision(session_id: str, request: DecisionRequest):
    try:
        from datetime import date
        decision = PlayerDecision(
            decision_type=request.decision_type,
            parameters=request.parameters,
            timestamp=date.today(),
            narrative=request.narrative
        )
        
        impacts = game_manager.apply_decision(session_id, decision)
        state = game_manager.get_state(session_id)
        
        return {
            "success": True,
            "impacts": impacts,
            "new_state": {
                "cash": state.cash,
                "revenue_mtd": state.revenue_mtd,
                "costs_mtd": state.costs_mtd,
                "kpis": state.kpis
            }
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.get("/{session_id}/state")
def get_game_state(session_id: str):
    state = game_manager.get_state(session_id)
    if not state:
        raise HTTPException(status_code=404, detail=f"Game session not found: {session_id}")
    
    pnl_gen = StatementGenerator()
    pnl_data = pnl_gen.generate_p_and_l(state)
    
    return {
        "session_id": session_id,
        "current_date": str(state.current_date),
        "week_number": state.week_number,
        "cash": state.cash,
        "revenue_mtd": state.revenue_mtd,
        "costs_mtd": state.costs_mtd,
        "capacity_utilization": state.capacity_utilization,
        "customer_satisfaction": state.customer_satisfaction,
        "kpis": state.kpis,
        "financial_statements": {
            "income_statement": pnl_data
        }
    }

# Add this request model
class ActionRequest(BaseModel):
    action_type: Literal["look", "talk", "hack", "use"]
    target_id: str  # e.g., "coffee_machine", "window", "hr_rep"

# --- ADD THIS NEW ENDPOINT ---
@router.post("/{session_id}/action")
def player_action(session_id: str, request: ActionRequest):
    state = game_manager.get_state(session_id)
    if not state:
        raise HTTPException(status_code=404, detail="Session not found")

    response_text = "You can't do that."
    
    # 1. TALK LOGIC
    if request.action_type == "talk":
        if request.target_id == "coffee_machine_oracle":
            response_text = "The interns are whispering: 'I heard the supplier in China is doubling prices next week.'"
        elif request.target_id == "hr_rep":
            if state.employee_morale < 0.5:
                response_text = "HR sighs. 'People are quitting. We need to fix the culture.'"
            else:
                response_text = "HR smiles. 'Everyone is excited about the new direction!'"

    # 2. LOOK LOGIC
    elif request.action_type == "look":
        if request.target_id == "window":
            response_text = "Downtown is glowing. If only our revenue looked that bright."

    # 3. HACK LOGIC (The "Audit Score" mechanic)
    elif request.action_type == "hack":
        if request.target_id == "competitor_database":
            state.audit_score += 10 # Risk increases!
            response_text = "Access Granted: Competitor is launching a product next month."
            
    return {
        "narrative": response_text,
        "audit_score": state.audit_score,
        "inbox_unread": sum(1 for m in state.inbox if not m.read)
    }