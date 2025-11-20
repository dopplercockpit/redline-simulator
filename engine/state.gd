# res://engine/state.gd
extends Resource
class_name GameState
const VERSION := "1.0.0"

# Cash & accruals
var cash: float = 0.0
var revenue_ytd: float = 0.0
var expense_ytd: float = 0.0

# Domain
var fleet := {}          # {"A320ceo": {"count":4, "lease_usd_mpm":220000, "hours_avail":10.5, "age_avg":8.2}}
var routes := {}         # {"LYS–BCN": {"weekly_freq":10, "price_usd":99, "capacity_seats":180, "demand_idx":0.76}}
var fuel := {"price_usd_per_ton": 830.0, "hedge_pct": 0.2, "hedge_price": 700.0}

# KPIs / rolling counters (reset on month close where noted)
var kpis := {}           # "ask", "rpk" rolling; plus derived CASK/RASK/LF
var meta := {}           # scenario metadata

func reset():
	cash = 0.0
	revenue_ytd = 0.0
	expense_ytd = 0.0
	fleet = {}
	routes = {}
	fuel = {"price_usd_per_ton": 830.0, "hedge_pct": 0.2, "hedge_price": 700.0}
	kpis = {}
	meta = {}

func load_config(cfg: Dictionary):
	for k in cfg.keys():
		self.set(k, cfg[k])

# Calculate financial summary on the fly based on operational state
func get_financial_summary() -> Dictionary:
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
