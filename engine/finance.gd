# res://engine/Finance.gd
extends Resource

# Tunable placeholders for Sprint 1
const CREW_COST_PER_FLIGHT_USD := 3500.0
const AIRPORT_COST_PER_FLIGHT_USD := 1200.0
const AVG_STAGE_LENGTH_KM := 900.0   # simplification until routes.json
const KG_FUEL_PER_FLIGHT := 4500.0   # crude baseline; refine later

func apply_day(_state: Resource, _date: Dictionary) -> void:
	# Deprecated: daily simulation is disabled by design. Use calculate_week_delta().
	push_warning("Finance.apply_day is deprecated. Use DecisionResolver + calculate_week_delta().")

func calculate_week_delta(state: Resource) -> Dictionary:
	var week_ask: float = 0.0
	var week_rpk: float = 0.0
	var week_revenue: float = 0.0
	var week_cost: float = 0.0

	# Weekly frequencies are already expressed per week.
	for route_name in state.routes.keys():
		var r: Dictionary = state.routes[route_name]

		var weekly_freq: float = float(r.get("weekly_freq", 0))
		var flights_week: float = weekly_freq
		if flights_week <= 0.0:
			continue

		var seats: float = float(r.get("capacity_seats", 0))
		var price: float = float(r.get("price_usd", 0))
		var demand_idx: float = clamp(float(r.get("demand_idx", 0.7)), 0.0, 1.2)

		# Offered seat-km (ASK) and sold seat-km (RPK proxy)
		var ask_route: float = flights_week * seats * AVG_STAGE_LENGTH_KM
		var load_factor: float = clamp(demand_idx, 0.05, 0.98)
		var rpk_route: float = ask_route * load_factor

		# Revenue (ultra-simple: pax * seats * LF)
		var pax: float = flights_week * seats * load_factor
		var revenue_route: float = pax * price

		# Costs
		var fuel_price: float = float(state.fuel.get("price_usd_per_ton", 800.0))
		var hedge_pct: float = float(state.fuel.get("hedge_pct", 0.0))
		var hedge_price: float = float(state.fuel.get("hedge_price", fuel_price))
		var effective_fuel_price: float = (hedge_pct * hedge_price) + ((1.0 - hedge_pct) * fuel_price)
		var fuel_tons: float = (KG_FUEL_PER_FLIGHT / 1000.0) * flights_week
		var fuel_cost: float = effective_fuel_price * fuel_tons

		var crew_cost: float = CREW_COST_PER_FLIGHT_USD * flights_week
		var airport_cost: float = AIRPORT_COST_PER_FLIGHT_USD * flights_week
		var lease_cost: float = _lease_cost_weekly(state)  # monthly lease spread across 4 weeks

		# Aggregate
		week_ask += ask_route
		week_rpk += rpk_route
		week_revenue += revenue_route
		week_cost += (fuel_cost + crew_cost + airport_cost + lease_cost)

	return {
		"ask_delta": week_ask,
		"rpk_delta": week_rpk,
		"revenue_delta": week_revenue,
		"expense_delta": week_cost,
		"cash_delta": (week_revenue - week_cost)
	}

func close_month(state: Resource, month_id: int) -> Dictionary:
	var ask: float = max(float(state.kpis.get("ask", 0.0)), 1.0)
	var rpk: float = float(state.kpis.get("rpk", 0.0))

	var cask: float = float(state.expense_ytd) / ask
	var rask: float = float(state.revenue_ytd) / ask
	var lf: float = rpk / ask

	var report: Dictionary = {
		"month": month_id,
		"rev_ytd": state.revenue_ytd,
		"exp_ytd": state.expense_ytd,
		"cash": state.cash,
		"cask": cask,
		"rask": rask,
		"lf": lf
	}

	# Reset rolling counters for next month aggregation
	state.kpis.erase("ask")
	state.kpis.erase("rpk")

	return report

func _lease_cost_weekly(state: Resource) -> float:
	# Sum monthly lease by aircraft type, spread over 4 weeks
	var monthly: float = 0.0
	for t in state.fleet.keys():
		var a: Dictionary = state.fleet[t]
		monthly += float(a.get("lease_usd_mpm", 0.0)) * float(a.get("count", 0))
	return monthly / 4.0
