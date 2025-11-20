"""
backend/models/chart_of_accounts.py
The Static Architecture of the Redline P&L
Designed for FP&A & RGM Simulation
"""

from pydantic import BaseModel
from typing import Literal, Optional

class AccountLine(BaseModel):
    id: int
    name: str
    parent_id: Optional[int] = None
    sign: Literal[1, -1] = 1  # 1 for Revenue (Credit), -1 for Expense (Debit)
    type: Literal["revenue", "cogs", "opex", "below_line"] = "revenue"
    behavior: Literal["variable", "fixed", "step_fixed"] = "variable"
    description: str = ""
    game_lever: str = ""  # Hint for the player on what affects this


P_AND_L_STRUCTURE = [
    # ---------------------------------------------------------
    # 4000: REVENUE (The Top Line)
    # ---------------------------------------------------------
    {
        "id": 4000,
        "name": "GROSS TICKET REVENUE",
        "sign": 1,
        "type": "revenue",
        "behavior": "variable",
        "description": "Total value of tickets sold before discounts.",
        "game_lever": "Pricing Decisions, Route Demand"
    },
    {
        "id": 4100,
        "name": "Ancillary Revenue",
        "sign": 1,
        "type": "revenue",
        "behavior": "variable",
        "description": "Baggage fees, seat selection, onboard WiFi.",
        "game_lever": "Add-on Pricing, Customer Segmentation"
    },
    {
        "id": 4200,
        "name": "Gross-to-Net Adjustments",
        "sign": -1,
        "type": "revenue",
        "behavior": "variable",
        "description": "Discounts, Corporate Rebates, Credit Card Fees.",
        "game_lever": "Channel Mix, Sales Contracts"
    },
    # CALCULATION POINT: NET REVENUE = 4000 + 4100 - 4200

    # ---------------------------------------------------------
    # 5000: DIRECT OPERATING COSTS (COGS / Variable)
    # ---------------------------------------------------------
    {
        "id": 5000,
        "name": "Fuel Expenses",
        "sign": -1,
        "type": "cogs",
        "behavior": "variable",
        "description": "Jet A-1 Fuel costs. Highly volatile.",
        "game_lever": "Fuel Hedging, Aircraft Efficiency"
    },
    {
        "id": 5100,
        "name": "Airport & Handling Fees",
        "sign": -1,
        "type": "cogs",
        "behavior": "step_fixed",
        "description": "Landing fees, gate leases, ground handling.",
        "game_lever": "Route Selection, Airport Contracts"
    },
    {
        "id": 5200,
        "name": "Flight Crew Salaries",
        "sign": -1,
        "type": "cogs",
        "behavior": "step_fixed",
        "description": "Pilots and Cabin Crew (Union Contracts).",
        "game_lever": "Capacity, Union Negotiations"
    },
    {
        "id": 5300,
        "name": "Maintenance (Direct)",
        "sign": -1,
        "type": "cogs",
        "behavior": "variable",
        "description": "Hourly maintenance checks based on flight hours.",
        "game_lever": "Fleet Age, Utilization"
    },
    {
        "id": 5400,
        "name": "In-Flight Catering",
        "sign": -1,
        "type": "cogs",
        "behavior": "variable",
        "description": "Food and Beverage costs per passenger.",
        "game_lever": "Service Level Decisions"
    },
    # CALCULATION POINT: GROSS MARGIN = NET REVENUE - SUM(5000s)

    # ---------------------------------------------------------
    # 6000: OPERATING EXPENSES (OPEX / SG&A)
    # ---------------------------------------------------------
    {
        "id": 6000,
        "name": "Sales & Marketing",
        "sign": -1,
        "type": "opex",
        "behavior": "fixed",
        "description": "Brand advertising, commission to travel agents.",
        "game_lever": "Marketing Budget"
    },
    {
        "id": 6100,
        "name": "General & Admin (HQ)",
        "sign": -1,
        "type": "opex",
        "behavior": "fixed",
        "description": "Executive salaries, HQ rent, IT systems.",
        "game_lever": "Cost Cutting Initiatives"
    },
    {
        "id": 6200,
        "name": "Insurance",
        "sign": -1,
        "type": "opex",
        "behavior": "fixed",
        "description": "Hull and liability insurance.",
        "game_lever": "Safety Rating, Fleet Value"
    },
    # CALCULATION POINT: EBITDAR = GROSS MARGIN - SUM(6000s)

    # ---------------------------------------------------------
    # 7000: AIRCRAFT RENT & OWNERSHIP
    # ---------------------------------------------------------
    {
        "id": 7000,
        "name": "Aircraft Leasing Costs",
        "sign": -1,
        "type": "below_line",
        "behavior": "fixed",
        "description": "Operating leases for aircraft.",
        "game_lever": "Fleet Strategy (Buy vs Lease)"
    },
    # CALCULATION POINT: EBITDA = EBITDAR - 7000

    {
        "id": 7100,
        "name": "Depreciation & Amortization",
        "sign": -1,
        "type": "below_line",
        "behavior": "fixed",
        "description": "Depreciation of owned aircraft and assets.",
        "game_lever": "CAPEX"
    },
    # CALCULATION POINT: EBIT (Operating Profit) = EBITDA - 7100

    # ---------------------------------------------------------
    # 8000: INTEREST & TAXES
    # ---------------------------------------------------------
    {
        "id": 8000,
        "name": "Interest Expense",
        "sign": -1,
        "type": "below_line",
        "behavior": "fixed",
        "description": "Cost of debt financing.",
        "game_lever": "Debt Structure, Credit Rating"
    },
    {
        "id": 8100,
        "name": "Corporate Taxes",
        "sign": -1,
        "type": "below_line",
        "behavior": "variable",
        "description": "State and Federal taxes.",
        "game_lever": "Profitability"
    }
    # CALCULATION POINT: NET INCOME = EBIT - 8000 - 8100
]