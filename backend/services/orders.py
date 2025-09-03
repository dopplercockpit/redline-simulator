"""
backend/services/orders.py

Sprint 3: Order pricing + postings.
This version removes broken imports of Order/OrderLine from master.py and
any phantom services.pricing module. Everything lives here.
"""

from __future__ import annotations
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Optional, Dict, Any

# Finance ledger
from ..services.finance.ledger_store import post_balanced_je
# Costing (this one exists in models/master.py)
from ..models.master import rollup_std_cost

# ── Account constants (tweak IDs if your seed uses different codes) ───────────
ACCT_CASH   = "1000"
ACCT_AR     = "1100"
ACCT_INV    = "1200"  # Inventory – Finished Goods
ACCT_REV    = "4000"
ACCT_CONTRA = "4100"  # Sales Discounts & Allowances (contra to revenue)
ACCT_COGS   = "5000"

TWOPLACES = Decimal("0.01")
def _q(x: float | int) -> float:
    return float(Decimal(str(x)).quantize(TWOPLACES, rounding=ROUND_HALF_UP))

# ==============================================================================
# Pricing logic (formerly compute_pricing_waterfall)
# ==============================================================================

def compute_pricing_waterfall(input_obj: any):
    """
    Robust pricing engine:
    - Accepts any object with .units, .list_price, .conditions (each condition has .basis, .value, .scope, .sign, .sequence)
    - Normalizes strings (AMOUNT/PERCENT, TOTAL/UNIT, +/-)
    - Ignores invalid/empty conditions (value <= 0 or missing)
    - Amounts:
        AMOUNT: value is per-unit unless scope=="TOTAL" (then split per-unit for calc but report total)
        PERCENT: value is % of current net unit price
    """
    base_unit_price = float(getattr(input_obj, "list_price", 0.0))
    units = float(getattr(input_obj, "units", 0.0))
    conditions = list(getattr(input_obj, "conditions", [])) or []

    # Normalize & filter conditions
    norm = []
    for c in conditions:
        basis = str(getattr(c, "basis", "AMOUNT")).upper()
        scope = str(getattr(c, "scope", "TOTAL")).upper()
        sign  = str(getattr(c, "sign", "-")).strip() or "-"
        try:
            value = float(getattr(c, "value", 0.0))
        except (TypeError, ValueError):
            value = 0.0
        try:
            seq = int(getattr(c, "sequence", 100))
        except (TypeError, ValueError):
            seq = 100

        # ignore zeros/negatives
        if value <= 0:
            continue

        norm.append({
            "code":  getattr(c, "code", "") or "",
            "label": getattr(c, "label", "") or "",
            "basis": basis if basis in ("AMOUNT", "PERCENT") else "AMOUNT",
            "scope": scope if scope in ("TOTAL", "UNIT") else "TOTAL",
            "sign":  sign if sign in ("-", "+") else "-",
            "value": value,
            "sequence": seq,
        })

    norm.sort(key=lambda x: x["sequence"])

    steps = []
    net_unit = base_unit_price

    for c in norm:
        if c["basis"] == "AMOUNT":
            # amount is per-unit; if scope is TOTAL, convert to per-unit for math
            per_unit_amt = c["value"] if c["scope"] == "UNIT" else (c["value"] / max(units, 1.0))
        else:  # PERCENT
            per_unit_amt = (c["value"] / 100.0) * net_unit

        if c["sign"] == "-":
            net_unit -= per_unit_amt
        else:
            net_unit += per_unit_amt

        reported_amt = per_unit_amt * units if c["scope"] == "TOTAL" or c["basis"] == "PERCENT" else per_unit_amt
        steps.append({
            "code": c["code"],
            "label": c["label"],
            "sign": c["sign"],
            "amount": round(reported_amt, 2),
        })

    class Result: pass
    out = Result()
    out.base_unit_price = base_unit_price
    out.steps = steps
    return out


    norm.sort(key=lambda x: x["sequence"])

    steps = []
    net_unit = base_unit_price

    for c in norm:
        if c["basis"] == "AMOUNT":
            # amount is per-unit; if scope is TOTAL, convert to per-unit for math
            per_unit_amt = c["value"] if c["scope"] == "UNIT" else (c["value"] / max(units, 1.0))
        else:  # PERCENT
            per_unit_amt = (c["value"] / 100.0) * net_unit

        if c["sign"] == "-":
            net_unit -= per_unit_amt
        else:
            net_unit += per_unit_amt

        reported_amt = per_unit_amt * units if c["scope"] == "TOTAL" or c["basis"] == "PERCENT" else per_unit_amt
        steps.append({
            "code": c["code"],
            "label": c["label"],
            "sign": c["sign"],
            "amount": round(reported_amt, 2),
        })

    class Result: pass
    out = Result()
    out.base_unit_price = base_unit_price
    out.steps = steps
    return out


    class Result: pass
    result = Result()
    result.base_unit_price = base_price
    result.steps = steps
    return result

# ==============================================================================
# Totals
# ==============================================================================

def compute_order_totals(order) -> dict:
    """
    Compute gross, discounts, and net revenue for an order-like object.
    Order.lines must have: units, list_price, conditions.
    """
    gross = 0.0
    discounts = 0.0

    for line in order.lines:
        wf = compute_pricing_waterfall(line)
        base_unit = float(getattr(wf, "base_unit_price", line.list_price))
        line_gross = base_unit * float(line.units)
        gross += line_gross

        for s in wf.steps:
            amt = s["amount"]
            if s["sign"] == "-" and amt > 0:
                discounts += amt
            elif s["sign"] == "+" and amt < 0:
                discounts += abs(amt)

    net = gross - discounts
    return {
        "gross_price": _q(gross),
        "total_discounts": _q(discounts),
        "net_revenue": _q(net),
    }

# ==============================================================================
# Postings
# ==============================================================================

def confirm_order_posting(order, je_date: Optional[date] = None) -> str:
    je_date = je_date or date.today()
    totals = compute_order_totals(order)
    memo = f"Order {order.order_id} confirmation"

    lines = [
        {"account": ACCT_AR, "debit": totals["net_revenue"]},
        {"account": ACCT_REV, "credit": totals["gross_price"]},
    ]
    if totals["total_discounts"] > 0:
        lines.insert(1, {"account": ACCT_CONTRA, "debit": totals["total_discounts"]})

    je_id = f"CONF-{order.order_id}"
    post_balanced_je(je_id, je_date, memo, lines)
    return je_id

def ship_order_posting(order, je_date: Optional[date] = None) -> str:
    je_date = je_date or date.today()
    total_cost = 0.0
    for line in order.lines:
        units = float(line.units)
        std = rollup_std_cost(line.material_id)
        total_cost += units * std

    memo = f"Order {order.order_id} shipment COGS"
    lines = [
        {"account": ACCT_COGS, "debit": _q(total_cost)},
        {"account": ACCT_INV, "credit": _q(total_cost)},
    ]
    je_id = f"SHIP-{order.order_id}"
    post_balanced_je(je_id, je_date, memo, lines)
    return je_id

def cash_receipt_posting(order, cash_amount: float, early_pay_discount: float = 0.0, je_date: Optional[date] = None) -> str:
    je_date = je_date or date.today()
    disc = _q(early_pay_discount or 0.0)
    cash_amount = _q(cash_amount)
    memo = f"Order {order.order_id} cash receipt"

    lines = [{"account": ACCT_CASH, "debit": cash_amount}]
    if disc > 0:
        lines.append({"account": ACCT_CONTRA, "debit": disc})
    lines.append({"account": ACCT_AR, "credit": _q(cash_amount + disc)})

    je_id = f"RCPT-{order.order_id}"
    post_balanced_je(je_id, je_date, memo, lines)
    return je_id

def return_order_posting(order, return_amount: float, return_cost: float, je_date: Optional[date] = None) -> list[str]:
    je_date = je_date or date.today()
    return_amount = _q(return_amount)
    return_cost = _q(return_cost)
    memo = f"Order {order.order_id} return"

    lines_rev = [
        {"account": ACCT_REV, "debit": return_amount},
        {"account": ACCT_CONTRA, "credit": return_amount},
    ]
    je1 = f"RET-REV-{order.order_id}"
    post_balanced_je(je1, je_date, memo + " (rev)", lines_rev)

    lines_cogs = [
        {"account": ACCT_INV, "debit": return_cost},
        {"account": ACCT_COGS, "credit": return_cost},
    ]
    je2 = f"RET-COGS-{order.order_id}"
    post_balanced_je(je2, je_date, memo + " (cogs)", lines_cogs)

    return [je1, je2]
