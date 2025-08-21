
# backend/services/orders.py
from __future__ import annotations
from dataclasses import dataclass
from datetime import date
from typing import List
from .finance.ledger_store import get_ledger
from ..models.journal import JournalEntry, JournalLine
from ..models.master import CUSTOMERS, MATERIALS, rollup_std_cost
from .finance.revenue import (
    PricingCondition, PricingWaterfallInput, compute_pricing_waterfall
)

@dataclass
class OrderLine:
    material_id: str
    units: float
    list_price: float
    conditions: List[PricingCondition]

@dataclass
class Order:
    order_id: str
    order_date: date
    customer_id: str
    lines: List[OrderLine]

def price_order(o: Order):
    """Returns pricing results per line and grand total."""
    priced_lines = []
    grand_total = 0.0
    for ln in o.lines:
        res = compute_pricing_waterfall(PricingWaterfallInput(
            units=ln.units, list_price=ln.list_price, conditions=ln.conditions
        ))
        priced_lines.append({
            "material_id": ln.material_id,
            "units": ln.units,
            "base_unit_price": res.base_unit_price,
            "final_unit_price": res.final_unit_price,
            "final_line_amount": res.final_line_amount,
            "steps": [s.__dict__ for s in res.steps],
        })
        grand_total += res.final_line_amount
    return {
        "order_id": o.order_id,
        "customer": CUSTOMERS[o.customer_id].name,
        "lines": priced_lines,
        "net_amount": round(grand_total, 2)
    }

def confirm_order(o: Order, priced_summary: dict):
    """Posts AR / Revenue for net amount (order booked)."""
    L = get_ledger()
    amt = priced_summary["net_amount"]
    je = JournalEntry(
        je_id=f"SO-{o.order_id}",
        je_date=o.order_date,
        memo=f"Book order {o.order_id} - customer {o.customer_id}",
        lines=[
            JournalLine("1100", debit=amt),     # A/R
            JournalLine("4000", credit=amt),    # Revenue (Net Sales)
        ]
    )
    L.post(je)
    return {"posted": True, "amount": amt}

def ship_order(order_id: str, ship_date: date, material_id: str, units: float):
    """Consumes BOM std cost and posts COGS/Inventory on shipment."""
    L = get_ledger()
    # std cost per finished unit
    per_unit = rollup_std_cost(material_id)
    cogs = round(per_unit * units, 2)
    # JE: DR COGS, CR Inventory
    je = JournalEntry(
        je_id=f"SHP-{order_id}",
        je_date=ship_date,
        memo=f"Ship {units} x {material_id}",
        lines=[
            JournalLine("5000", debit=cogs),   # COGS
            JournalLine("1200", credit=cogs),  # Inventory
        ]
    )
    L.post(je)
    return {"posted": True, "cogs": cogs, "per_unit_cost": per_unit}
