# res://engine/state.gd
extends Resource
class_name GameStateData
# GameStateData class is registered globally in Project Settings
const VERSION := "1.0.0"

# NOTE: Business state must be mutated only via DecisionResolver.

# Cash & accruals
var cash: float = 0.0
var revenue_ytd: float = 0.0
var expense_ytd: float = 0.0
var revenue_mtd: float = 0.0
var expense_mtd: float = 0.0
var is_month_end: bool = false

# Domain
var fleet := {}          # {"A320ceo": {"count":4, "lease_usd_mpm":220000, "hours_avail":10.5, "age_avg":8.2}}
var routes := {}         # {"LYS-BCN": {"weekly_freq":10, "price_usd":99, "capacity_seats":180, "demand_idx":0.76}}
var fuel := {"price_usd_per_ton": 830.0, "hedge_pct": 0.2, "hedge_price": 700.0}

# KPIs / rolling counters (reset on month close where noted)
var kpis := {}           # "ask", "rpk" rolling; plus derived CASK/RASK/LF
var meta := {}           # scenario metadata

func reset() -> void:
	cash = 0.0
	revenue_ytd = 0.0
	expense_ytd = 0.0
	revenue_mtd = 0.0
	expense_mtd = 0.0
	fleet = {}
	routes = {}
	fuel = {"price_usd_per_ton": 830.0, "hedge_pct": 0.2, "hedge_price": 700.0}
	kpis = {}
	meta = {}

func load_config(cfg: Dictionary) -> void:
	for k in cfg.keys():
		self.set(k, cfg[k])

func load_from_statements(income_statement: Dictionary, balance_sheet: Dictionary, cash_flow: Dictionary) -> void:
	# Temporary bridge: store raw statements and set basic aggregates.
	meta["financial_statements"] = {
		"income_statement": income_statement,
		"balance_sheet": balance_sheet,
		"cash_flow": cash_flow
	}
	if cash_flow.has("ending_cash"):
		cash = float(cash_flow.get("ending_cash", cash))
	if income_statement.has("net_sales"):
		revenue_ytd = float(income_statement.get("net_sales", revenue_ytd))
	if income_statement.has("cogs") or income_statement.has("opex"):
		expense_ytd = float(income_statement.get("cogs", 0.0)) + float(income_statement.get("opex", 0.0))

# Calculate financial summary on the fly based on operational state
func get_financial_summary() -> Dictionary:
	if meta.has("financial_statements") and typeof(meta["financial_statements"]) == TYPE_DICTIONARY:
		var fs: Dictionary = meta["financial_statements"] as Dictionary
		var income: Dictionary = fs.get("income_statement", {}) as Dictionary
		var balance: Dictionary = fs.get("balance_sheet", {}) as Dictionary
		var cash_flow: Dictionary = fs.get("cash_flow", {}) as Dictionary
		if not income.is_empty() or not balance.is_empty() or not cash_flow.is_empty():
			return {
			"income_statement": income,
			"balance_sheet": balance,
			"cash_flow": cash_flow
			}
	var monthly_lease_cost = 0.0
	for plane_type in fleet:
		var p = fleet[plane_type]
		monthly_lease_cost += p["count"] * p["lease_usd_mpm"]

	# Calculate fuel costs based on routes (simplified)
	var monthly_fuel_cost = 0.0
	for route_id in routes:
		var r = routes[route_id]
		var weekly_flights = r.get("weekly_freq", 0)
		var fuel_per_flight = 5.0  # Assumption: 5 tons per flight
		monthly_fuel_cost += weekly_flights * 4 * fuel_per_flight * fuel["price_usd_per_ton"]

	# Calculate ticket revenue (simplified)
	var monthly_ticket_rev = 0.0
	for route_id in routes:
		var r = routes[route_id]
		var weekly_flights = r.get("weekly_freq", 0)
		var price = r.get("price_usd", 0)
		var capacity = r.get("capacity_seats", 180)
		var demand = r.get("demand_idx", 0.7)
		monthly_ticket_rev += weekly_flights * 4 * price * capacity * demand

	var ancillary_rev = monthly_ticket_rev * 0.15  # 15% upsell assumption
	var total_rev = monthly_ticket_rev + ancillary_rev

	# Simplified operating costs
	var crew_costs = fleet.size() * 50000.0  # Assumption per fleet type
	var airport_fees = monthly_ticket_rev * 0.08  # 8% of revenue
	var maintenance = fleet.size() * 30000.0

	# Calculate EBITDAR and Net Income
	var ebitdar = total_rev - monthly_fuel_cost - crew_costs - airport_fees - maintenance
	var net_income = ebitdar - monthly_lease_cost

	# Return the dictionary structured for the FinancialPanel
	return {
		"income_statement": {
			"ticket_rev": monthly_ticket_rev,
			"ancillary_rev": ancillary_rev,
			"total_rev": total_rev,
			"fuel_costs": monthly_fuel_cost,
			"crew_costs": crew_costs,
			"airport_fees": airport_fees,
			"maintenance": maintenance,
			"leasing_costs": monthly_lease_cost,
			"ebitdar": ebitdar,
			"net_income": net_income
		},
		"balance_sheet": {
			"cash": cash,
			"receivables": monthly_ticket_rev * 0.10,  # 10% in receivables
			"rotable_parts": fleet.size() * 500000.0,  # Spare parts inventory
			"flight_equipment": 0.0,  # Assume all leased for MVP
			"rou_assets": monthly_lease_cost * 12 * 5,  # Rough valuation of leased planes
			"total_assets": cash + (monthly_ticket_rev * 0.10) + (fleet.size() * 500000.0) + (monthly_lease_cost * 12 * 5),
			"accounts_payable": monthly_fuel_cost * 0.5,  # Simplified
			"air_traffic_liab": monthly_ticket_rev * 0.30,  # 30% unearned (future flights)
			"lease_liabilities": monthly_lease_cost * 12 * 5,
			"long_term_debt": 0.0,
			"equity": cash - (monthly_fuel_cost * 0.5) - (monthly_ticket_rev * 0.30) - (monthly_lease_cost * 12 * 5)
		},
		"cash_flow": {
			"net_income": net_income,
			"change_in_working_capital": 0.0,
			"capex": 0.0,
			"debt_activity": 0.0,
			"equity_activity": 0.0,
			"net_change_in_cash": net_income,
			"ending_cash": cash + net_income
		}
	}
