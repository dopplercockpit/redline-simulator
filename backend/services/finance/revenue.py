# backend/services/finance/revenue.py
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Literal

class AllowanceType(str, Enum):
    STRUCTURAL = "STRUCTURAL"     # long-term agreements: channel rebates, freight allowances
    PROMOTIONAL = "PROMOTIONAL"   # promos/trade spend
    INVOICE = "INVOICE"           # defectives, early-pay discount, short-ships
    CANCELLED = "CANCELLED"       # cancelled/returned invoiced orders

class Basis(str, Enum):
    PERCENT = "PERCENT"  # percent of base
    AMOUNT = "AMOUNT"    # absolute amount (per unit or total; see scope)

class Scope(str, Enum):
    PER_UNIT = "PER_UNIT"  # condition applied per unit
    TOTAL = "TOTAL"        # condition applied on the overall line amount

class ConditionCode(str, Enum):
    PR00 = "PR00"        # Base list price (implicit; can keep as a named base row)
    K007 = "K007"        # Customer discount (structural)
    ZR01 = "ZR01"        # Promotional discount (promo)
    SKTO = "SKTO"        # Early payment discount (invoice)
    ZFR1 = "ZFR1"        # Freight (can be +/-; often +)
    ZSUR = "ZSUR"        # Surcharge (e.g., commodity spike)
    ZVOL = "ZVOL"        # Volume/Tier discount
    ZREB = "ZREB"        # Rebate accrual estimate (structural; contra-revenue analysis)
    ZFX  = "ZFX"         # FX adjustment
    ZRND = "ZRND"        # Rounding

@dataclass
class RevenueWaterfallInput:
    units: float
    list_price: float           # price per unit before conditions
    structural_allowances: float = 0.0
    promotional_allowances: float = 0.0
    invoice_allowances: float = 0.0
    cancelled_orders: float = 0.0

@dataclass
class RevenueWaterfallResult:
    gross_sales: float
    structural_allowances: float
    promotional_allowances: float
    invoice_allowances: float
    cancelled_orders: float
    total_minorations: float
    net_sales: float

def compute_revenue_waterfall(i: RevenueWaterfallInput) -> RevenueWaterfallResult:
    gross = round(i.units * i.list_price, 2)
    total_min = round(i.structural_allowances + i.promotional_allowances + i.invoice_allowances + i.cancelled_orders, 2)
    net = round(gross + total_min, 2)  # allowances are negative numbers by convention
    return RevenueWaterfallResult(
        gross_sales=gross,
        structural_allowances=round(i.structural_allowances, 2),
        promotional_allowances=round(i.promotional_allowances, 2),
        invoice_allowances=round(i.invoice_allowances, 2),
        cancelled_orders=round(i.cancelled_orders, 2),
        total_minorations=total_min,
        net_sales=net,
    )

# ---------- Pricing condition waterfall (per sales line) ----------

@dataclass
class PricingCondition:
    code: str                      # e.g., "K007"
    label: str                     # "Customer Discount"
    basis: Basis                   # PERCENT or AMOUNT
    value: float                   # 10 for 10% | 5000 for $5k
    scope: Scope = Scope.TOTAL     # TOTAL or PER_UNIT
    sign: Literal["-", "+"] = "-"  # "-" discount | "+" surcharge
    category: AllowanceType | None = None   # STRUCTURAL/PROMOTIONAL/INVOICE or None
    sequence: int = 100            # evaluation order (lower runs first)
    active_from: str | None = None # ISO date "2025-09-01"
    active_to: str | None = None
    currency: str | None = None    # "USD" (future multi‑currency)
    min_floor: float | None = None # optional minimum price per unit
    max_ceiling: float | None = None # optional maximum price per unit
    customer_id: str | None = None # optional match key
    material_id: str | None = None # optional match key

@dataclass
class PricingWaterfallInput:
    units: float
    list_price: float             # per unit
    conditions: List[PricingCondition] = field(default_factory=list)

@dataclass
class PricingStep:
    code: str
    label: str
    amount: float                 # signed amount for this step
    interim_unit_price: float     # price per unit after this step
    interim_line_amount: float    # line total after this step

@dataclass
class PricingWaterfallResult:
    base_unit_price: float
    base_line_amount: float
    steps: List[PricingStep]
    final_unit_price: float
    final_line_amount: float

def _cond_amount(units: float, base_line: float, base_unit: float, c: PricingCondition) -> float:
    # Compute signed condition amount (negative for discounts if sign == "-")
    if c.scope == Scope.PER_UNIT:
        raw = c.value if c.basis == Basis.AMOUNT else (base_unit * c.value / 100.0)
        amt = raw * units
    else:  # TOTAL
        if c.basis == Basis.AMOUNT:
            amt = c.value
        else:
            amt = base_line * c.value / 100.0
    return -abs(amt) if c.sign == "-" else abs(amt)

def compute_pricing_waterfall(i: PricingWaterfallInput) -> PricingWaterfallResult:
    unit_price = i.list_price
    line_amount = round(i.units * unit_price, 2)
    steps: List[PricingStep] = []

    # NEW: sort & (optionally) filter by active dates/customer/material upstream later
    conds = sorted(i.conditions, key=lambda c: c.sequence)

    for c in conds:
        amt = _cond_amount(i.units, line_amount, unit_price, c)
        new_line = round(line_amount + amt, 2)
        new_unit = round(new_line / i.units, 6) if i.units else unit_price

        # NEW: apply floor/ceiling if set
        if c.min_floor is not None and new_unit < c.min_floor:
            diff = round((c.min_floor * i.units) - new_line, 2)
            new_unit = c.min_floor
            new_line = round(new_unit * i.units, 2)
            amt = round(amt + diff, 2)  # adjust the condition’s effective amount

        if c.max_ceiling is not None and new_unit > c.max_ceiling:
            diff = round((c.max_ceiling * i.units) - new_line, 2)
            new_unit = c.max_ceiling
            new_line = round(new_unit * i.units, 2)
            amt = round(amt + diff, 2)

        steps.append(PricingStep(
            code=c.code, label=c.label, amount=round(amt, 2),
            interim_unit_price=new_unit, interim_line_amount=new_line
        ))
        unit_price, line_amount = new_unit, new_line

    return PricingWaterfallResult(
        base_unit_price=i.list_price,
        base_line_amount=round(i.units * i.list_price, 2),
        steps=steps,
        final_unit_price=round(unit_price, 6),
        final_line_amount=round(line_amount, 2),
    )

