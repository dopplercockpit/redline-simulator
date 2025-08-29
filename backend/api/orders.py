# backend/api/orders.py
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date
from types import SimpleNamespace

# Pricing engine (exists)
#from ..services.pricing import compute_pricing_waterfall
# Posting functions (exist, expect objects with these attrs: order_id, order_date, customer_id, lines[*].material_id/units/list_price/conditions)
from ..services.orders import compute_pricing_waterfall
from ..services.orders import (
    confirm_order_posting,
    ship_order_posting,
    cash_receipt_posting,
    return_order_posting,
)

router = APIRouter(prefix="/orders", tags=["orders"])

# ------------------------------------------------------------------------------
# Request schema (what Swagger shows)
# ------------------------------------------------------------------------------
class ConditionReq(BaseModel):
    code: str
    label: str
    basis: str                   # keep as str to avoid enum import issues
    value: float
    scope: str = "TOTAL"
    sign: str = "-"
    category: Optional[str] = None
    sequence: int = 100

class OrderLineReq(BaseModel):
    material_id: str
    units: float = Field(..., gt=0)
    list_price: float = Field(..., gt=0)
    conditions: List[ConditionReq] = []

class OrderReq(BaseModel):
    order_id: str
    order_date: date
    customer_id: str
    lines: List[OrderLineReq]

# ------------------------------------------------------------------------------
# Local “lite” types to avoid importing missing models
# ------------------------------------------------------------------------------
class PricingConditionLite:
    def __init__(self, **kw):
        # mirror expected attributes used by your pricing engine
        self.code = kw.get("code", "")
        self.label = kw.get("label", "")
        self.basis = kw.get("basis", "AMOUNT")
        self.value = kw.get("value", 0.0)
        self.scope = kw.get("scope", "TOTAL")
        self.sign = kw.get("sign", "-")
        self.category = kw.get("category")
        self.sequence = kw.get("sequence", 100)

class PricingWaterfallInputLite:
    def __init__(self, *, units: float, list_price: float, conditions: List[PricingConditionLite]):
        self.units = units
        self.list_price = list_price
        self.conditions = conditions

def _to_order_like(req: OrderReq) -> SimpleNamespace:
    """Builds a duck-typed object with attrs expected by service posting funcs."""
    lines = []
    for l in req.lines:
        conds = [PricingConditionLite(**c.model_dump()) for c in l.conditions]
        lines.append(SimpleNamespace(
            material_id=l.material_id,
            units=l.units,
            list_price=l.list_price,
            conditions=conds
        ))
    return SimpleNamespace(
        order_id=req.order_id,
        order_date=req.order_date,
        customer_id=req.customer_id,
        lines=lines
    )

# ------------------------------------------------------------------------------
# /price — uses pricing engine but with lite inputs to avoid import errors
# ------------------------------------------------------------------------------
@router.post("/price")
def api_price_order(req: OrderReq):
    gross = 0.0
    discounts = 0.0
    out_lines = []

    for l in req.lines:
        wfin = PricingWaterfallInputLite(
            units=l.units,
            list_price=l.list_price,
            conditions=[PricingConditionLite(**c.model_dump()) for c in l.conditions],
        )
        wf = compute_pricing_waterfall(wfin)  # your engine should only read .units/.list_price/.conditions[*]

        base_unit = float(getattr(wf, "base_unit_price", l.list_price))
        line_gross = base_unit * float(l.units)
        line_disc = 0.0
        steps_out = []
        for s in getattr(wf, "steps", []):
            amt = float(getattr(s, "amount", 0.0))
            sign = getattr(s, "sign", "-")
            if sign == "-" and amt > 0:
                line_disc += amt
            elif sign == "+" and amt < 0:
                line_disc += abs(amt)
            steps_out.append({
                "code": getattr(s, "code", ""),
                "label": getattr(s, "label", ""),
                "sign": sign,
                "amount": amt
            })
        net_line = line_gross - line_disc
        gross += line_gross
        discounts += line_disc

        out_lines.append({
            "material_id": l.material_id,
            "units": l.units,
            "base_unit_price": base_unit,
            "steps": steps_out,
            "net_line_amount": round(net_line, 2)
        })

    return {
        "order_id": req.order_id,
        "lines": out_lines,
        "totals": {
            "gross_price": round(gross, 2),
            "total_discounts": round(discounts, 2),
            "net_revenue": round(gross - discounts, 2),
        },
    }

# ------------------------------------------------------------------------------
# Back-compat route names (mapped to Sprint-3 posting under the hood)
# ------------------------------------------------------------------------------
class ConfirmReq(BaseModel):
    order: OrderReq
    summary_net_amount: float

@router.post("/confirm")
def api_confirm_order(req: ConfirmReq):
    o_like = _to_order_like(req.order)
    confirm_order_posting(o_like, je_date=None)
    return {"confirmed": True, "order_id": o_like.order_id}

class ShipReq(BaseModel):
    order_id: str
    ship_date: date
    material_id: str
    units: float = Field(..., gt=0)

@router.post("/ship")
def api_ship(req: ShipReq):
    o_like = SimpleNamespace(
        order_id=req.order_id,
        order_date=req.ship_date,
        customer_id="UNKNOWN",
        lines=[SimpleNamespace(material_id=req.material_id, units=req.units, list_price=0.0, conditions=[])]
    )
    ship_order_posting(o_like, je_date=req.ship_date)
    return {"shipped": True, "order_id": req.order_id}

# ------------------------------------------------------------------------------
# Explicit posting endpoints (Sprint-3)
# ------------------------------------------------------------------------------
class OrderOnlyReq(BaseModel):
    order: OrderReq
    je_date: Optional[date] = None

@router.post("/{order_id}/confirm_posting")
def api_posting_confirm(order_id: str, body: OrderOnlyReq):
    o_like = _to_order_like(body.order)
    confirm_order_posting(o_like, body.je_date)
    return {"confirmed": True, "order_id": order_id}

class ShipPostingReq(BaseModel):
    order: OrderReq
    je_date: Optional[date] = None

@router.post("/{order_id}/ship_posting")
def api_posting_ship(order_id: str, body: ShipPostingReq):
    o_like = _to_order_like(body.order)
    ship_order_posting(o_like, body.je_date)
    return {"shipped": True, "order_id": order_id}

class ReceiptPostingReq(BaseModel):
    order: OrderReq
    cash_amount: float = Field(..., example=1000.0)
    early_pay_discount: float = Field(0.0, example=0.0)
    je_date: Optional[date] = None

@router.post("/{order_id}/receipt_posting")
def api_posting_receipt(order_id: str, body: ReceiptPostingReq):
    o_like = _to_order_like(body.order)
    cash_receipt_posting(o_like, body.cash_amount, body.early_pay_discount, body.je_date)
    return {"received": True, "order_id": order_id, "cash": body.cash_amount, "discount": body.early_pay_discount}

class ReturnPostingReq(BaseModel):
    order: OrderReq
    return_amount: float = Field(..., example=200.0)
    return_cost: float = Field(..., example=150.0)
    je_date: Optional[date] = None

@router.post("/{order_id}/return_posting")
def api_posting_return(order_id: str, body: ReturnPostingReq):
    o_like = _to_order_like(body.order)
    return_order_posting(o_like, body.return_amount, body.return_cost, body.je_date)
    return {"returned": True, "order_id": order_id, "amount": body.return_amount}
