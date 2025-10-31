# res://engine/Finance.gd
extends Resource

# Tunable placeholders for Sprint 1
const CREW_COST_PER_FLIGHT_USD := 3500.0
const AIRPORT_COST_PER_FLIGHT_USD := 1200.0
const AVG_STAGE_LENGTH_KM := 900.0   # simplification until routes.json
const KG_FUEL_PER_FLIGHT := 4500.0   # crude baseline; refine later

func apply_day(state: Resource, date: Dictionary) -> void:
	var day_ask: float = 0.0
	var day_rpk: float = 0.0
	var day_revenue: float = 0.0
	var day_cost: float = 0.0

	# Distribute weekly frequencies evenly across 7 days
	for route_name in state.routes.keys():
		var r: Dictionary = state.routes[route_name]

		var weekly_freq: float = float(r.get("weekly_freq", 0))
		var flights_today: float = weekly_freq / 7.0
		if flights_today <= 0.0:
			continue

		var seats: float = float(r.get("capacity_seats", 0))
		var price: float = float(r.get("price_usd", 0))
		var demand_idx: float = clamp(float(r.get("demand_idx", 0.7)), 0.0, 1.2)

		# Offered seat-km (ASK) and sold seat-km (RPK proxy)
		var ask_route: float = flights_today * seats * AVG_STAGE_LENGTH_KM
		var load_factor: float = clamp(demand_idx, 0.05, 0.98)  # MVP LF from demand index
		var rpk_route: float = ask_route * load_factor

		# Revenue (ultra-simple: pax ≈ seats * LF)
		var pax: float = flights_today * seats * load_factor
		var revenue_route: float = pax * price

		# Costs
		var fuel_price: float = float(state.fuel.get("price_usd_per_ton", 800.0))
		var hedge_pct: float = float(state.fuel.get("hedge_pct", 0.0))
		var hedge_price: float = float(state.fuel.get("hedge_price", fuel_price))
		var effective_fuel_price: float = (hedge_pct * hedge_price) + ((1.0 - hedge_pct) * fuel_price)
		var fuel_tons: float = (KG_FUEL_PER_FLIGHT / 1000.0) * flights_today
		var fuel_cost: float = effective_fuel_price * fuel_tons

		var crew_cost: float = CREW_COST_PER_FLIGHT_USD * flights_today
		var airport_cost: float = AIRPORT_COST_PER_FLIGHT_USD * flights_today
		var lease_cost: float = _lease_cost_daily(state)  # monthly lease spread across 28 days

		# Aggregate
		day_ask += ask_route
		day_rpk += rpk_route
		day_revenue += revenue_route
		day_cost += (fuel_cost + crew_cost + airport_cost + lease_cost)

	# Accrue into YTD
	state.kpis["ask"] = float(state.kpis.get("ask", 0.0)) + day_ask
	state.kpis["rpk"] = float(state.kpis.get("rpk", 0.0)) + day_rpk
	state.revenue_ytd = float(state.revenue_ytd) + day_revenue
	state.expense_ytd = float(state.expense_ytd) + day_cost

	# Cash timing (MVP): ticket cash ~= revenue; costs hit same day
	state.cash = float(state.cash) + (day_revenue - day_cost)

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

func _lease_cost_daily(state: Resource) -> float:
	# Sum monthly lease by aircraft type, spread over 28 days
	var monthly: float = 0.0
	for t in state.fleet.keys():
		var a: Dictionary = state.fleet[t]
		monthly += float(a.get("lease_usd_mpm", 0.0)) * float(a.get("count", 0))
	return monthly / 28.0
