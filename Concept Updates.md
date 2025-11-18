This clarifies everything. The good news is that your **backend logic (`state.gd`) is actually ahead of your UI**. You don't need to rewrite the engine; you just need to update the "dashboard" (UI) to reflect the data that is already there.

To achieve your goal of an **Airline MVP** while keeping the architecture modular for future industries (Retail, CPG), here are the correct next steps.

### **Step 1: Re-Label the Financial Panel (The "Skin")**

Your `FinancialPanel.gd` is currently hardcoded for a factory (WIP, Finished Goods). We need to make these labels dynamic or switch them to Airline standard terms (USALI - Uniform System of Accounts for the Lodging Industry is similar, but for Airlines, we use standard IATA-style P\&L).

**Action:** Open `res://ui/FinancialPanel.gd` and update the `income_lines` and `balance_lines` arrays to match an airline model.

**Replace lines 20-45 in `FinancialPanel.gd` with this:**

```gdscript
# res://ui/FinancialPanel.gd

# AIRLINE P&L STRUCTURE
var income_lines: Array = [
    ["ticket_rev", "Passenger Revenue"],
    ["ancillary_rev", "Ancillary Revenue (Bags/Seats)"],
    ["total_rev", "Total Revenue"],
    ["fuel_costs", "Fuel Costs"],
    ["crew_costs", "Crew & Salaries"],
    ["airport_fees", "Landing & Navigation Fees"],
    ["maintenance", "MRO (Maintenance)"],
    ["leasing_costs", "Aircraft Leases"],
    ["ebitdar", "EBITDAR"], # Important Airline Metric (Earnings Before Interest, Taxes, Depreciation, Amortization, and Restructuring/Rent)
    ["net_income", "Net Income"]
]

# AIRLINE BALANCE SHEET
var balance_lines: Array = [
    ["cash", "Cash & Equivalents"],
    ["receivables", "Accounts Receivable (OTA/Credit Cards)"],
    ["rotable_parts", "Spare Parts Inventory"], # Replaces "WIP"
    ["flight_equipment", "Flight Equipment (Owned)"],
    ["rou_assets", "Right-of-Use Assets (Leased Planes)"], # IFRS 16 standard for airlines
    ["total_assets", "Total Assets"],
    ["accounts_payable", "Accounts Payable"],
    ["air_traffic_liab", "Unearned Revenue (Future Flights)"], # Crucial for Airlines (Cash received but flight hasn't happened)
    ["lease_liabilities", "Lease Liabilities"],
    ["long_term_debt", "Long Term Debt"],
    ["equity", "Shareholder Equity"]
]
```

### **Step 2: Update the Data Mapping in `state.gd`**

Your `state.gd` has the raw data (`fleet`, `routes`, `fuel`), but it needs to calculate the financial summary lines that the UI now expects (like `ticket_rev` or `leasing_costs`).

**Action:** Add a helper function in `res://engine/state.gd` that summarizes the raw operational data into financial lines.

```gdscript
# res://engine/state.gd

# ... existing variables ...

# Calculate financial summary on the fly based on operational state
func get_financial_summary() -> Dictionary:
    var monthly_lease_cost = 0.0
    for plane_type in fleet:
        var p = fleet[plane_type]
        monthly_lease_cost += p["count"] * p["lease_usd_mpm"]

    var monthly_fuel_cost = 0.0 # You would calculate this based on routes * distance * fuel price
    
    # Return the dictionary structured for the FinancialPanel
    return {
        "income_statement": {
            "ticket_rev": revenue_ytd, # Placeholder, replace with actual logic
            "ancillary_rev": revenue_ytd * 0.15, # Assumption: 15% upsell
            "total_rev": revenue_ytd * 1.15,
            "leasing_costs": monthly_lease_cost,
            "fuel_costs": monthly_fuel_cost,
            # ... fill in other calculated fields ...
        },
        "balance_sheet": {
            "cash": cash,
            "rou_assets": monthly_lease_cost * 12 * 5, # Rough valuation of leased planes
            "equity": cash - 50000 # Simplified equity logic
        }
    }
```

### **Step 3: Align "Game Flow" (Weeks/Months) to Airlines**

The "Turn-based" logic in your Word doc (Week 1-3: Action, Week 4: Close) fits perfectly, but the **nature of the actions** must change.

  * **Factory (Old):** "Shipments delayed", "Machine breakdown", "Inventory build-up".
  * **Airline (New):** \* **Week 1 (Revenue Management):** Adjust pricing for the "LYS-BCN" route. Demand is high? Raise prices (yield management).
      * **Week 2 (Operations):** A plane has an "AOG" (Aircraft on Ground) technical issue. Do you lease a spot-market plane (expensive) or cancel the flight (refunds + reputation hit)?
      * **Week 3 (Fuel):** Oil prices spike. Do you lock in a hedge contract?
      * **Week 4 (Month End):** Reconcile "Unearned Revenue" (tickets sold for future flights) vs. "Flown Revenue".

**Action:** Create a `GameManager` (autoload) to track the calendar.

```gdscript
# res://engine/GameManager.gd
extends Node

var current_week: int = 1
var current_month: int = 1
var is_month_end: bool = false

func advance_turn():
    current_week += 1
    if current_week % 4 == 0:
        is_month_end = true
        # Trigger "Month End Close" Mission
    else:
        is_month_end = false
        # Trigger random operational event (Weather delay, Strike, Fuel spike)
```

### **Step 4: Retain Modular Design (The "Plug-in" Approach)**

You mentioned eventually plugging in other industries (CPG, Retail). To do this, do **not** hardcode the lines in `FinancialPanel.gd` forever.

**Future-Proofing Strategy:**
Instead of hardcoding `income_lines` in the UI script, pass them *with* the data packet from the engine.

1.  **Engine (`state.gd`):** Defines the industry type ("AIRLINE").
2.  **Config:** Load a JSON file (`industry_config.json`) that defines the P\&L row names for that industry.
3.  **UI:** specific reads the JSON and builds the rows.

**For MVP:** Hardcoding the Airline lines (Step 1) is acceptable to get the demo running fast.

### **Summary of Next Steps**

1.  **Update `FinancialPanel.gd`**: Paste the Airline P\&L arrays provided in Step 1.
2.  **Update `state.gd`**: Add the `get_financial_summary()` function to translate `fleet`/`routes` data into P\&L numbers.
3.  **Update `cfo_office.gd`**: Change the `_on_hotspot_laptop_input_event` to call `state.get_financial_summary()` instead of loading the static `redline_financials.json`.
4.  **Update Hotspots:** In the Word doc, rename "Inventory Dashboard" to **"Network Planning"** and "Factory View" to **"Tarmac View"**.

This pivots your project successfully to the Airline MVP while using the code you already have.