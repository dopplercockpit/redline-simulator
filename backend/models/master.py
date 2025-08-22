
# backend/models/master.py
from dataclasses import dataclass
from typing import Dict, List

@dataclass(frozen=True)
class Customer:
    id: str
    name: str
    pay_terms: str = "N30"   # e.g., "2/10 N30" (not used in JE yet)

@dataclass(frozen=True)
class Supplier:                    
    id: str
    name: str
    pay_terms: str = "N30"

@dataclass(frozen=True)
class Material:
    id: str
    desc: str
    uom: str
    type: str  # RAW | FG
    std_cost: float

@dataclass(frozen=True)
class BomLine:
    component_id: str
    qty_per: float
    scrap_pct: float = 0.0

@dataclass(frozen=True)
class Bom:
    finished_id: str
    lines: List[BomLine]

# ---- Dummy data ----
CUSTOMERS: Dict[str, Customer] = {
    "CUST-RETAIL": Customer("CUST-RETAIL", "Big Box Retailer", "1/29 N30"),
    "CUST-FLEET":  Customer("CUST-FLEET",  "Fleet Buyer LLC", "N45"),
}

SUPPLIERS: Dict[str, Supplier] = {         
    # filled by seeds
}

MATERIALS: Dict[str, Material] = {
    # Finished engine
    "ENG-V6": Material("ENG-V6", "V6 Engine", "EA", "FG", 0.0),  # std cost rolled from BOM
    # Raw parts
    "RM-BLOCK": Material("RM-BLOCK", "Engine Block Casting", "EA", "RAW", 180.0),
    "RM-HEAD":  Material("RM-HEAD",  "Cylinder Head", "EA", "RAW", 80.0),
    "RM-ECU":   Material("RM-ECU",   "Engine Control Unit", "EA", "RAW", 95.0),
}

BOMS: Dict[str, Bom] = {
    "ENG-V6": Bom("ENG-V6", [
        BomLine("RM-BLOCK", 1.0),
        BomLine("RM-HEAD",  2.0),
        BomLine("RM-ECU",   1.0),
    ])
}

def rollup_std_cost(finished_id: str) -> float:
    bom = BOMS.get(finished_id)
    if not bom:
        return MATERIALS[finished_id].std_cost
    cost = 0.0
    for line in bom.lines:
        comp = MATERIALS[line.component_id]
        eff_qty = line.qty_per * (1.0 + line.scrap_pct)
        cost += comp.std_cost * eff_qty
    return round(cost, 2)
