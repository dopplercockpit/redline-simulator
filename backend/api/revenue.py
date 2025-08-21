
# backend/api/revenue.py
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Literal, Optional
from ..services.finance.revenue import (
    RevenueWaterfallInput, compute_revenue_waterfall,
    PricingCondition, PricingWaterfallInput, compute_pricing_waterfall,
    Basis, Scope, AllowanceType
)

router = APIRouter(prefix="/finance/revenue", tags=["revenue"])

# ---------- Pydantic models for request/response ----------

class RevenueWaterfallReq(BaseModel):
    units: float = Field(..., gt=0)
    list_price: float = Field(..., gt=0)
    structural_allowances: float = 0.0
    promotional_allowances: float = 0.0
    invoice_allowances: float = 0.0
    cancelled_orders: float = 0.0

class RevenueWaterfallResp(BaseModel):
    gross_sales: float
    structural_allowances: float
    promotional_allowances: float
    invoice_allowances: float
    cancelled_orders: float
    total_minorations: float
    net_sales: float

class PricingConditionReq(BaseModel):
    code: str
    label: str
    basis: Basis
    value: float
    scope: Scope = Scope.TOTAL
    sign: Literal["-","+"] = "-"
    category: Optional[AllowanceType] = None
    sequence: int = 100
    active_from: Optional[str] = None
    active_to: Optional[str] = None
    currency: Optional[str] = None
    min_floor: Optional[float] = None
    max_ceiling: Optional[float] = None
    customer_id: Optional[str] = None
    material_id: Optional[str] = None

class PricingWaterfallReq(BaseModel):
    units: float = Field(..., gt=0)
    list_price: float = Field(..., gt=0)
    conditions: List[PricingConditionReq] = []

@router.post("/waterfall", response_model=RevenueWaterfallResp)
def revenue_waterfall(req: RevenueWaterfallReq):
    res = compute_revenue_waterfall(RevenueWaterfallInput(**req.model_dump()))
    return res.__dict__

@router.post("/pricing", response_model=dict)
def pricing_waterfall(req: PricingWaterfallReq):
    # convert incoming conditions to dataclass list
    conds = [PricingCondition(**c.model_dump()) for c in req.conditions]
    res = compute_pricing_waterfall(PricingWaterfallInput(
        units=req.units, list_price=req.list_price, conditions=conds
    ))
    return {
        "base_unit_price": res.base_unit_price,
        "base_line_amount": res.base_line_amount,
        "steps": [s.__dict__ for s in res.steps],
        "final_unit_price": res.final_unit_price,
        "final_line_amount": res.final_line_amount,
    }
