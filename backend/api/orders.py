# backend/api/orders.py
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import List, Optional, Literal
from datetime import date
from ..services.orders import Order, OrderLine, price_order, confirm_order, ship_order
from ..services.finance.revenue import PricingCondition, Basis, Scope, AllowanceType

router = APIRouter(prefix="/orders", tags=["orders"])

class ConditionReq(BaseModel):
    code: str
    label: str
    basis: Basis
    value: float
    scope: Scope = Scope.TOTAL
    sign: Literal["-","+"] = "-"
    category: Optional[AllowanceType] = None
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

@router.post("/price")
def api_price_order(req: OrderReq):
    o = Order(
        order_id=req.order_id, order_date=req.order_date, customer_id=req.customer_id,
        lines=[OrderLine(
            material_id=l.material_id, units=l.units, list_price=l.list_price,
            conditions=[PricingCondition(**c.model_dump()) for c in l.conditions]
        ) for l in req.lines]
    )
    return price_order(o)

class ConfirmReq(BaseModel):
    order: OrderReq
    summary_net_amount: float

@router.post("/confirm")
def api_confirm_order(req: ConfirmReq):
    o = Order(
        order_id=req.order.order_id, order_date=req.order.order_date, customer_id=req.order.customer_id,
        lines=[OrderLine(
            material_id=l.material_id, units=l.units, list_price=l.list_price,
            conditions=[PricingCondition(**c.model_dump()) for c in l.conditions]
        ) for l in req.order.lines]
    )
    return confirm_order(o, {"net_amount": req.summary_net_amount})

class ShipReq(BaseModel):
    order_id: str
    ship_date: date
    material_id: str
    units: float = Field(..., gt=0)

@router.post("/ship")
def api_ship(req: ShipReq):
    return ship_order(req.order_id, req.ship_date, req.material_id, req.units)
