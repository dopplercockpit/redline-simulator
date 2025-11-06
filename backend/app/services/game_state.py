# =====================================================
# SECTION 1: BACKEND - GAME STATE MANAGER
# File: backend/app/services/game_state.py
# =====================================================

"""
# backend/app/services/game_state.py
Game State Manager - Central orchestrator for Redline Simulator
"""

from typing import Dict, List, Optional, Any
from datetime import date, timedelta
from pydantic import BaseModel, Field
from enum import Enum
import json
import random

class DecisionType(str, Enum):
    PRICING = "pricing"
    CAPACITY = "capacity"
    WORKING_CAPITAL = "working_capital"
    FINANCING = "financing"
    COST_CUTTING = "cost_cutting"

class GamePhase(str, Enum):
    WEEK_START = "week_start"
    MID_WEEK = "mid_week" 
    WEEK_END = "week_end"
    MONTH_END = "month_end"

class PlayerDecision(BaseModel):
    decision_type: DecisionType
    parameters: Dict[str, Any]
    timestamp: date
    narrative: Optional[str] = None

class GameState(BaseModel):
    session_id: str
    scenario_id: str
    current_date: date
    week_number: int = 1
    month_number: int = 1
    phase: GamePhase = GamePhase.WEEK_START
    cash: float = 1000000.0
    revenue_mtd: float = 0.0
    costs_mtd: float = 0.0
    capacity_utilization: float = 0.75
    customer_satisfaction: float = 0.80
    employee_morale: float = 0.75
    audit_risk: float = 0.0
    market_volatility: float = 0.5
    decisions: List[PlayerDecision] = Field(default_factory=list)
    pending_events: List[Dict] = Field(default_factory=list)
    kpis: Dict[str, float] = Field(default_factory=dict)

class GameStateManager:
    def __init__(self):
        self.states: Dict[str, GameState] = {}
        self.scenarios = self._load_scenarios()
        self.rng = random.Random()
        
    def _load_scenarios(self) -> Dict:
        try:
            with open("data/redline_scenarios_v3.json", "r") as f:
                data = json.load(f)
                return {s["id"]: s for s in data.get("scenarios", [])}
        except:
            return {}
    
    def new_game(self, session_id: str, scenario_id: str, seed: Optional[int] = None) -> GameState:
        if seed:
            self.rng.seed(seed)
        
        scenario = self.scenarios.get(scenario_id, {})
        state = GameState(
            session_id=session_id,
            scenario_id=scenario_id,
            current_date=date(2025, 1, 1),
            cash=scenario.get("starting_cash", 1000000.0)
        )
        
        self.states[session_id] = state
        state.pending_events = self._generate_events(state)
        return state
    
    def tick(self, session_id: str, days: int = 1) -> GameState:
        state = self.states.get(session_id)
        if not state:
            raise ValueError(f"No game session: {session_id}")
        
        for _ in range(days):
            state.current_date += timedelta(days=1)
            self._process_daily_operations(state)
            
            if state.current_date.weekday() == 0:
                state.phase = GamePhase.WEEK_START
                state.week_number += 1
            elif state.current_date.weekday() == 4:
                state.phase = GamePhase.WEEK_END
                self._process_week_end(state)
        
        return state
    
    def apply_decision(self, session_id: str, decision: PlayerDecision) -> Dict:
        state = self.states.get(session_id)
        if not state:
            raise ValueError(f"No game session: {session_id}")
        
        state.decisions.append(decision)
        impacts = {}
        
        if decision.decision_type == DecisionType.PRICING:
            impacts = self._apply_pricing_decision(state, decision.parameters)
        elif decision.decision_type == DecisionType.CAPACITY:
            impacts = self._apply_capacity_decision(state, decision.parameters)
        elif decision.decision_type == DecisionType.WORKING_CAPITAL:
            impacts = self._apply_working_capital_decision(state, decision.parameters)
        
        self._update_kpis(state)
        return impacts
    
    def _apply_pricing_decision(self, state: GameState, params: Dict) -> Dict:
        price_change = params.get("price_change_pct", 0) / 100.0
        elasticity = -1.5
        volume_impact = elasticity * price_change
        
        base_revenue = 500000
        new_revenue = base_revenue * (1 + price_change) * (1 + volume_impact)
        revenue_delta = new_revenue - base_revenue
        
        state.revenue_mtd += revenue_delta
        
        if price_change > 0.05:
            state.customer_satisfaction *= 0.95
        elif price_change < -0.05:
            state.customer_satisfaction = min(1.0, state.customer_satisfaction * 1.05)
        
        return {
            "revenue_impact": revenue_delta,
            "volume_impact": volume_impact,
            "customer_satisfaction": state.customer_satisfaction
        }
    
    def _apply_capacity_decision(self, state: GameState, params: Dict) -> Dict:
        capacity_change = params.get("capacity_change_pct", 0) / 100.0
        cost_per_capacity = 50000
        cost_impact = cost_per_capacity * capacity_change * 10
        
        state.capacity_utilization = min(1.0, state.capacity_utilization * (1 + capacity_change))
        state.costs_mtd += cost_impact
        state.cash -= cost_impact
        
        return {
            "cost_impact": cost_impact,
            "new_capacity": state.capacity_utilization
        }
    
    def _apply_working_capital_decision(self, state: GameState, params: Dict) -> Dict:
        ar_days_change = params.get("ar_days_change", 0)
        ap_days_change = params.get("ap_days_change", 0)
        
        daily_revenue = state.revenue_mtd / 30 if state.revenue_mtd else 10000
        daily_costs = state.costs_mtd / 30 if state.costs_mtd else 7000
        
        ar_impact = -ar_days_change * daily_revenue
        ap_impact = ap_days_change * daily_costs * 0.6
        
        total_cash_impact = ar_impact + ap_impact
        state.cash += total_cash_impact
        
        return {
            "cash_impact": total_cash_impact,
            "ar_impact": ar_impact,
            "ap_impact": ap_impact
        }
    
    def _process_daily_operations(self, state: GameState):
        daily_revenue = 500000 / 30
        daily_costs = 350000 / 30
        
        state.revenue_mtd += daily_revenue * state.capacity_utilization
        state.costs_mtd += daily_costs
        
        if self.rng.random() < 0.05:
            event = self.rng.choice([
                {"type": "supplier_issue", "impact": -50000},
                {"type": "bulk_order", "impact": 100000},
                {"type": "equipment_failure", "impact": -30000}
            ])
            state.pending_events.append(event)
    
    def _process_week_end(self, state: GameState):
        weekly_cash_flow = (state.revenue_mtd - state.costs_mtd) / 4
        state.cash += weekly_cash_flow
        state.kpis["weekly_cash_flow"] = weekly_cash_flow
        state.kpis["burn_rate"] = state.costs_mtd / 4
    
    def _generate_events(self, state: GameState) -> List[Dict]:
        events = []
        if state.market_volatility > 0.7:
            events.append({
                "type": "market_shock",
                "description": "Supply chain disruption detected",
                "choices": [
                    {"action": "expedite", "cost": 100000},
                    {"action": "wait", "risk": "stockout"}
                ]
            })
        return events
    
    def _update_kpis(self, state: GameState):
        state.kpis.update({
            "cash": state.cash,
            "capacity_utilization": state.capacity_utilization,
            "customer_satisfaction": state.customer_satisfaction,
            "employee_morale": state.employee_morale,
            "audit_risk": state.audit_risk,
            "decision_count": len(state.decisions)
        })
    
    def get_state(self, session_id: str) -> Optional[GameState]:
        return self.states.get(session_id)

game_manager = GameStateManager()