"""

backend/services/finance/statements.py
Generates the P&L Dictionary based on Game State
"""

from typing import Dict, Any
from backend.models.chart_of_accounts import P_AND_L_STRUCTURE
from backend.app.services.game_state import GameState


class StatementGenerator:

    def generate_p_and_l(self, state: GameState) -> Dict[str, Any]:
        """
        Takes the raw simulation state (clicks, hours flown, fuel burned)
        and maps it into the rigorous Chart of Accounts structure.
        """
        
        # 1. Calculate Raw Inputs from State (Simulation Logic)
        # In a real implementation, these come from the simulation history
        # using placeholders based on the simple state for MVP
        
        # Revenue Drivers
        volume = 1000  # proxy for pax
        base_price = 500
        
        # Cost Drivers
        fuel_price = 850  # per ton
        fuel_burn = 400  # tons
        
        # -----------------------------------------
        # MAPPING VALUES TO ACCOUNTS
        # -----------------------------------------
        
        # 4000: Revenue
        gross_ticket = state.revenue_mtd  # This is calculated in game_state.tick()
        ancillary = gross_ticket * 0.12  # 12% upsell
        discounts = gross_ticket * 0.05  # 5% leakage
        
        # 5000: COGS
        # Logic: Costs scale with utilization
        fuel_cost = (state.costs_mtd * 0.40)  # 40% of costs are fuel
        crew_cost = (state.costs_mtd * 0.20)
        landing_fees = (state.costs_mtd * 0.15)
        maintenance = (state.costs_mtd * 0.10)
        catering = (gross_ticket * 0.03)  # 3% of ticket sales
        
        # 6000: OPEX (Fixed)
        marketing = 50000  # Fixed monthly
        admin = 120000    # Fixed monthly
        insurance = 20000
        
        # 7000: Leases
        leases = 200000   # Fixed monthly for fleet
        depreciation = 15000
        
        # 8000: Financial
        interest = 5000
        
        # -----------------------------------------
        # BUILD THE LEDGER
        # -----------------------------------------
        ledger = {}
        
        # Map specific Account IDs to calculated values
        # In the future, this map can be dynamic based on a proper General Ledger (GL)
        ledger[4000] = gross_ticket
        ledger[4100] = ancillary
        ledger[4200] = discounts
        
        ledger[5000] = fuel_cost
        ledger[5100] = landing_fees
        ledger[5200] = crew_cost
        ledger[5300] = maintenance
        ledger[5400] = catering
        
        ledger[6000] = marketing
        ledger[6100] = admin
        ledger[6200] = insurance
        
        ledger[7000] = leases
        ledger[7100] = depreciation
        
        ledger[8000] = interest
        
        # -----------------------------------------
        # CALCULATE SUBTOTALS (The Waterfall)
        # -----------------------------------------
        
        # Net Revenue
        net_revenue = ledger[4000] + ledger[4100] - ledger[4200]
        
        # Total COGS
        total_cogs = sum([ledger[k] for k in [5000, 5100, 5200, 5300, 5400]])
        
        # Gross Margin
        gross_margin = net_revenue - total_cogs
        
        # Total OPEX
        total_opex = sum([ledger[k] for k in [6000, 6100, 6200]])
        
        # EBITDAR
        ebitdar = gross_margin - total_opex
        
        # EBITDA
        ebitda = ebitdar - ledger[7000]
        
        # EBIT
        ebit = ebitda - ledger[7100]
        
        # Taxes (Simplified 21% rate on positive EBIT)
        taxes = max(0, (ebit - interest) * 0.21)
        ledger[8100] = taxes
        
        # Net Income
        net_income = ebit - interest - taxes
        
        # -----------------------------------------
        # FORMAT FOR FRONTEND
        # -----------------------------------------
        # Returns a list of lines ready to render in the Godot GridContainer
        
        statement_lines = []
        
        # Helper to format line
        def add_line(label, value, type_="std", indent=0, lever=""):
            statement_lines.append({
                "label": label,
                "value": value,
                "type": type_,  # std, header, subtotal, total
                "indent": indent,
                "lever_hint": lever
            })

        add_line("REVENUE", None, "header")
        add_line("Gross Ticket Revenue", ledger[4000], "std", 0, "Pricing")
        add_line("Ancillary Revenue", ledger[4100], "std", 0, "Upsell")
        add_line("Less: Discounts & Adj.", ledger[4200], "std", 0, "Sales Strategy")
        add_line("NET REVENUE", net_revenue, "subtotal")
        
        add_line("DIRECT COSTS", None, "header")
        add_line("Fuel", ledger[5000], "std", 0, "Hedging")
        add_line("Crew", ledger[5200], "std", 0, "Rostering")
        add_line("Airport Fees", ledger[5100], "std", 0, "Route Mix")
        add_line("Maintenance", ledger[5300], "std", 0, "Fleet Age")
        add_line("Catering", ledger[5400], "std", 0, "Service Level")
        add_line("GROSS MARGIN", gross_margin, "subtotal")
        
        add_line("OPERATING EXPENSES", None, "header")
        add_line("Sales & Marketing", ledger[6000], "std", 0, "Ads")
        add_line("G&A (HQ)", ledger[6100], "std", 0, "Efficiency")
        add_line("Insurance", ledger[6200], "std", 0, "Risk")
        add_line("EBITDAR", ebitdar, "total", 0, "Operational Efficiency")
        
        add_line("Aircraft Leases", ledger[7000], "std", 0, "Financing")
        add_line("EBITDA", ebitda, "total")
        
        add_line("Depreciation", ledger[7100], "std", 0)
        add_line("EBIT (Operating Profit)", ebit, "total")
        
        add_line("Interest & Tax", ledger[8000] + ledger[8100], "std", 0)
        add_line("NET INCOME", net_income, "final_total")
        
        return {
            "lines": statement_lines,
            "kpis": {
                "gross_margin_pct": (gross_margin / net_revenue) if net_revenue else 0,
                "operating_margin_pct": (ebit / net_revenue) if net_revenue else 0,
                "net_margin_pct": (net_income / net_revenue) if net_revenue else 0
            }
        }
