# backend/seeds/baseline.py
from datetime import date
from dataclasses import dataclass
from typing import Dict, List
from ..services.finance.ledger_store import get_ledger, reset_ledger
from ..models.journal import JournalEntry, JournalLine
from ..models.master import (
    Customer, Supplier, Material, Bom, BomLine,
    CUSTOMERS, SUPPLIERS, MATERIALS, BOMS
)

# -------- Opening Balance Sheet --------
def post_opening_balance(as_of: date):
    """
    Posts the opening balance sheet via a single balanced JE.
    Accounts used:
      Cash(1000)  AR(1100)  Inventory(1200)  PPE(1500)
      AP(2000)    Accrued(2100)  Equity(3000)
    """
    L = get_ledger()
    # Opening amounts (USD) — tweak to taste
    cash = 300_000.00
    ar   =  20_000.00
    inv  =  50_000.00  # starting spare parts + some FGs
    ppe  = 300_000.00
    ap   =  40_000.00
    accr =  25_000.00
    equity = cash + ar + inv + ppe - ap - accr  # 605,000

    je = JournalEntry(
        je_id="OB-0001",
        je_date=as_of,
        memo="Opening Balance Sheet",
        lines=[
            JournalLine("1000", debit=cash),
            JournalLine("1100", debit=ar),
            JournalLine("1200", debit=inv),
            JournalLine("1500", debit=ppe),
            JournalLine("2000", credit=ap),
            JournalLine("2100", credit=accr),
            JournalLine("3000", credit=equity),
        ]
    )
    L.post(je)


# -------- Policies & Terms (MVP in-memory) --------

@dataclass(frozen=True)
class PaymentTerm:
    code: str      # e.g., "3N10" for 3% Net 10
    discount_pct: float
    discount_days: int
    net_days: int
    late_fee_pct_per_30: float = 0.0  # applied after > net_days (simple)

# your spec: 3% N10, 2% N15, 1% N29, N30, N45 (+ late fees >45)
PAYMENT_TERMS: Dict[str, PaymentTerm] = {
    "3N10": PaymentTerm("3N10", 0.03, 10, 10),
    "2N15": PaymentTerm("2N15", 0.02, 15, 15),
    "1N29": PaymentTerm("1N29", 0.01, 29, 29),
    "N30":  PaymentTerm("N30",  0.00,  0, 30),
    "N45":  PaymentTerm("N45",  0.00,  0, 45, late_fee_pct_per_30=0.01),
}

# Structural (always-on) and Promo caps (per instructor)
PRICING_POLICY = {
    "structural_max_pct": 12.0,   # cap across structural discounts
    "promo_max_pct": 10.0,        # cap across promo discounts
    "invoice_allow_max_pct": 3.0  # cap for invoice-level allowances
}

# Default terms:
CUSTOMER_TERMS: Dict[str, str] = {
    "CUST-RETAIL": "1N29",
    "CUST-FLEET":  "N45",
    "CUST-DIST":   "2N15",
}
SUPPLIER_TERMS: Dict[str, str] = {
    "SUPP-CAST": "2N15",
    "SUPP-ECU":  "N30",
    "SUPP-HEAD": "3N10",
}

# Default pricing conditions that auto-apply (SAP-style)
# Codes must match your revenue/pricing engine (K007=structural, ZR01=promo, ZFR1=freight)
DEFAULT_CUSTOMER_CONDITIONS: Dict[str, List[dict]] = {
    "CUST-RETAIL": [
        {"code":"K007","label":"Cust Disc","basis":"PERCENT","value":8,"sequence":20,"category":"STRUCTURAL"},
    ],
    "CUST-FLEET": [
        {"code":"K007","label":"Fleet Structural","basis":"PERCENT","value":6,"sequence":20,"category":"STRUCTURAL"},
    ],
    "CUST-DIST": [
        {"code":"K007","label":"Distributor Base","basis":"PERCENT","value":10,"sequence":20,"category":"STRUCTURAL"},
    ],
}
DEFAULT_MATERIAL_CONDITIONS: Dict[str, List[dict]] = {
    "ENG-V6":   [{"code":"ZFR1","label":"Freight","basis":"AMOUNT","value":15,"scope":"PER_UNIT","sequence":90,"sign":"+"}],
    "ENG-V8":   [{"code":"ZFR1","label":"Freight","basis":"AMOUNT","value":20,"scope":"PER_UNIT","sequence":90,"sign":"+"}],
    "ENG-I6":   [{"code":"ZFR1","label":"Freight","basis":"AMOUNT","value":12,"scope":"PER_UNIT","sequence":90,"sign":"+"}],
    "ENG-I4":   [{"code":"ZFR1","label":"Freight","basis":"AMOUNT","value":10,"scope":"PER_UNIT","sequence":90,"sign":"+"}],
    "ENG-HYB":  [{"code":"ZFR1","label":"Freight","basis":"AMOUNT","value":22,"scope":"PER_UNIT","sequence":90,"sign":"+"}],
    "ENG-EV":   [{"code":"ZFR1","label":"Freight","basis":"AMOUNT","value":25,"scope":"PER_UNIT","sequence":90,"sign":"+"}],
}

def install_master_data():
    """
    Extends the in-memory master data with engines + suppliers + BOMs.
    Idempotent: safe to call on reset.
    """
    # Customers
    CUSTOMERS.update({
        "CUST-DIST": Customer("CUST-DIST", "Northeast Distributor, Inc.", "2/15 N30"),
    })
    # Suppliers
    SUPPLIERS.update({
        "SUPP-CAST": Supplier("SUPP-CAST", "Alpha Castings"),
        "SUPP-ECU":  Supplier("SUPP-ECU", "Delta Electronics"),
        "SUPP-HEAD": Supplier("SUPP-HEAD", "Summit Machining"),
    })

    # Materials (finished engines + key raws)
    MATERIALS.update({
        "ENG-I4": Material("ENG-I4", "Inline-4 Engine", "EA", "FG", 0.0),
        "ENG-I6": Material("ENG-I6", "Inline-6 Engine", "EA", "FG", 0.0),
        "ENG-V6": Material("ENG-V6", "V6 Engine", "EA", "FG", 0.0),
        "ENG-V8": Material("ENG-V8", "V8 Engine", "EA", "FG", 0.0),
        "ENG-HYB":Material("ENG-HYB","Hybrid Engine", "EA", "FG", 0.0),
        "ENG-EV": Material("ENG-EV", "Electric Power Unit", "EA", "FG", 0.0),

        # Raw/Components (rough std costs)
        "RM-BLOCK": Material("RM-BLOCK", "Engine Block Casting", "EA", "RAW", 180.0),
        "RM-HEAD":  Material("RM-HEAD",  "Cylinder Head", "EA", "RAW", 80.0),
        "RM-ECU":   Material("RM-ECU",   "Engine Control Unit", "EA", "RAW", 95.0),
        "RM-BATT":  Material("RM-BATT",  "Battery Pack", "EA", "RAW", 420.0),
        "RM-MOTOR": Material("RM-MOTOR", "Electric Motor", "EA", "RAW", 520.0),
    })

    # BOMs (simple v1)
    BOMS.update({
        "ENG-I4":  Bom("ENG-I4",  [BomLine("RM-BLOCK",1.0), BomLine("RM-HEAD",1.0), BomLine("RM-ECU",1.0)]),
        "ENG-I6":  Bom("ENG-I6",  [BomLine("RM-BLOCK",1.0), BomLine("RM-HEAD",2.0), BomLine("RM-ECU",1.0)]),
        "ENG-V6":  Bom("ENG-V6",  [BomLine("RM-BLOCK",1.0), BomLine("RM-HEAD",2.0), BomLine("RM-ECU",1.0)]),
        "ENG-V8":  Bom("ENG-V8",  [BomLine("RM-BLOCK",1.0), BomLine("RM-HEAD",2.0), BomLine("RM-ECU",1.0)]),
        "ENG-HYB": Bom("ENG-HYB", [BomLine("RM-BLOCK",1.0), BomLine("RM-HEAD",2.0), BomLine("RM-ECU",1.0), BomLine("RM-BATT",1.0)]),
        "ENG-EV":  Bom("ENG-EV",  [BomLine("RM-MOTOR",1.0), BomLine("RM-BATT",1.0)]),
    })

def load_baseline(as_of: date):
    reset_ledger()
    install_master_data()
    post_opening_balance(as_of)
    # Nothing returned; state is loaded. Policies/terms live here:
    return {
        "as_of": str(as_of),
        "payment_terms": {k: vars(v) for k,v in PAYMENT_TERMS.items()},
        "pricing_policy": PRICING_POLICY,
        "customer_terms": CUSTOMER_TERMS,
        "supplier_terms": SUPPLIER_TERMS,
        "defaults": {
            "customer_conditions": DEFAULT_CUSTOMER_CONDITIONS,
            "material_conditions": DEFAULT_MATERIAL_CONDITIONS
        }
    }
