# res://engine/Finance.gd
extends Resource

# Tunable placeholders for Sprint 1
const CREW_COST_PER_FLIGHT_USD := 3500.0
const AIRPORT_COST_PER_FLIGHT_USD := 1200.0
const AVG_STAGE_LENGTH_KM := 900.0   # simplification until routes.json
const KG_FUEL_PER_FLIGHT := 4500.0   # crude baseline; refine later
const CASH_GL := "1000"
const REV_GL := "4000"
const EXP_GL := "5000"
const RETAINED_EARNINGS_GL := "3000"
const AR_GL := "1200"
const LANDING_FEES_REV_GL := "4000"
const PFC_REV_GL := "4100"
const CONCESSIONS_REV_GL := "4200"
const PAYROLL_EXP_GL := "5000"
const UTILITIES_EXP_GL := "5100"
const INTEREST_EXP_GL := "5600"

var _ledger := preload("res://engine/ledger.gd").new()

func apply_day(_state: Resource, _date: Dictionary) -> void:
	# Deprecated: daily simulation is disabled by design. Use calculate_week_delta().
	push_warning("Finance.apply_day is deprecated. Use DecisionResolver + calculate_week_delta().")

func calculate_week_delta(state: Resource) -> Dictionary:
	# PATCH 1: disabled legacy airline behavior because Airport CFO is canonical v0.1.
	# Kept for backwards-compatible airline scenarios and explicit legacy delta mode only.
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

func calculate_airport_week(state: Resource, week_number: int) -> Dictionary:
	var errors: Array[String] = []
	var posted := 0

	if not (state is GameStateData):
		return {
			"passenger_volume_delta": 0.0,
			"turnarounds_delta": 0.0,
			"revenue_delta": 0.0,
			"expense_delta": 0.0,
			"cash": 0.0,
			"posted": 0,
			"errors": ["calculate_airport_week requires GameStateData"]
		}

	var s := state as GameStateData
	ensure_coa_loaded(s)

	var airport: Dictionary = s.airport
	var commercial: Dictionary = s.commercial
	var economy: Dictionary = s.economy
	var revenue_streams: Dictionary = commercial.get("revenue_streams", {}) as Dictionary

	var tourism_index := maxf(float(economy.get("tourism_index", 55.0)), 1.0)
	var reputation := maxf(float(airport.get("reputation", 50.0)), 1.0)
	var service_quality_tier := int(airport.get("service_quality_tier", 1))
	var resilience_tier := int(airport.get("resilience_tier", 1))
	var airport_tier := int(airport.get("tier", 1))

	var traffic_modifier := (tourism_index / 55.0) * (reputation / 50.0)
	traffic_modifier *= 1.0 + (float(service_quality_tier - 1) * 0.03)
	traffic_modifier *= 1.0 + (float(resilience_tier - 1) * 0.02)

	var passenger_volume_week: float = round(18000.0 * traffic_modifier)
	var turnarounds_week: float = passenger_volume_week / 145.0

	var landing_fees: Dictionary = revenue_streams.get("landing_fees", {}) as Dictionary
	var passenger_fees: Dictionary = revenue_streams.get("passenger_fees", {}) as Dictionary
	var concessions: Dictionary = revenue_streams.get("concessions", {}) as Dictionary

	var landing_revenue: float = turnarounds_week * float(landing_fees.get("price_per_turnaround_usd", 850.0))
	var pfc_revenue: float = passenger_volume_week * float(passenger_fees.get("pax_facility_charge_usd", 8.0))
	var concessions_revenue: float = float(concessions.get("baseline_sales_usd_week", 180000.0)) * traffic_modifier * 0.18
	var payroll_expense: float = 175000.0 * (1.0 + maxf(float(airport_tier - 1), 0.0) * 0.08)
	var utilities_expense: float = 45000.0 * (1.0 + maxf(float(airport_tier - 1), 0.0) * 0.05)
	var interest_expense: float = _weekly_interest_expense(s.debt_stack)

	var scenario_id := str(s.meta.get("id", s.meta.get("scenario_id", "")))
	posted += _post_airport_tx(s, week_number, scenario_id, "Landing fees collected", CASH_GL, LANDING_FEES_REV_GL, landing_revenue, errors)
	posted += _post_airport_tx(s, week_number, scenario_id, "Passenger facility charges collected", CASH_GL, PFC_REV_GL, pfc_revenue, errors)
	posted += _post_airport_tx(s, week_number, scenario_id, "Concessions revenue collected", CASH_GL, CONCESSIONS_REV_GL, concessions_revenue, errors)
	posted += _post_airport_tx(s, week_number, scenario_id, "Payroll paid", PAYROLL_EXP_GL, CASH_GL, payroll_expense, errors)
	posted += _post_airport_tx(s, week_number, scenario_id, "Utilities paid", UTILITIES_EXP_GL, CASH_GL, utilities_expense, errors)
	if interest_expense > 0.0:
		posted += _post_airport_tx(s, week_number, scenario_id, "Interest paid", INTEREST_EXP_GL, CASH_GL, interest_expense, errors)

	var revenue_delta: float = landing_revenue + pfc_revenue + concessions_revenue
	var expense_delta: float = payroll_expense + utilities_expense + interest_expense

	s.cash = _ledger.get_gl_balance(s.ledger, CASH_GL)
	s.revenue_ytd = float(s.revenue_ytd) + revenue_delta
	s.expense_ytd = float(s.expense_ytd) + expense_delta
	s.revenue_mtd = float(s.revenue_mtd) + revenue_delta
	s.expense_mtd = float(s.expense_mtd) + expense_delta
	s.kpis["passenger_volume_mtd"] = float(s.kpis.get("passenger_volume_mtd", 0.0)) + passenger_volume_week
	s.kpis["passenger_volume_ytd"] = float(s.kpis.get("passenger_volume_ytd", 0.0)) + passenger_volume_week
	s.kpis["turnarounds_mtd"] = float(s.kpis.get("turnarounds_mtd", 0.0)) + turnarounds_week
	s.kpis["turnarounds_ytd"] = float(s.kpis.get("turnarounds_ytd", 0.0)) + turnarounds_week

	var statements := generate_statements_from_ledger(s)
	s.meta["financial_statements"] = statements

	return {
		"passenger_volume_delta": passenger_volume_week,
		"turnarounds_delta": turnarounds_week,
		"revenue_delta": revenue_delta,
		"expense_delta": expense_delta,
		"cash": s.cash,
		"posted": posted,
		"errors": errors
	}

# PATCH 2: LEDGER MODE
func ensure_coa_loaded(state: GameStateData) -> void:
	if typeof(state.coa) == TYPE_DICTIONARY and typeof(state.coa.get("accounts", null)) == TYPE_ARRAY:
		return
	if typeof(state.meta) != TYPE_DICTIONARY:
		return
	var coa_ref := str(state.meta.get("coa_ref", ""))
	if coa_ref == "":
		return

	var txt := FileAccess.get_file_as_string(coa_ref)
	if txt == "":
		return
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		state.coa = parsed as Dictionary

func generate_statements_from_ledger(state: GameStateData) -> Dictionary:
	ensure_coa_loaded(state)
	var statements: Dictionary = _ledger.build_statements(state.ledger, state.coa)
	var cash_flow: Dictionary = statements.get("cash_flow", {}) as Dictionary
	var ending_cash := float(cash_flow.get("ending_cash", _ledger.get_gl_balance(state.ledger, CASH_GL)))
	if typeof(state.meta) == TYPE_DICTIONARY and state.meta.has("cash_close_anchor"):
		var anchor := float(state.meta.get("cash_close_anchor", ending_cash))
		cash_flow["net_change_in_cash"] = ending_cash - anchor
	cash_flow["ending_cash"] = ending_cash
	statements["cash_flow"] = cash_flow
	return statements

func post_week(state: GameStateData, week_ctx: Dictionary) -> Dictionary:
	var delta: Dictionary = calculate_week_delta(state)
	var revenue_delta := float(delta.get("revenue_delta", 0.0))
	var expense_delta := float(delta.get("expense_delta", 0.0))
	var ask_delta := float(delta.get("ask_delta", 0.0))
	var rpk_delta := float(delta.get("rpk_delta", 0.0))
	var week_number := int(week_ctx.get("week_number", 0))
	var scenario_id := str(state.meta.get("id", ""))

	var posted := 0
	var errs: Array[String] = []

	# PATCH 2: use legacy delta math as the amount source, but post ledger entries.
	if revenue_delta > 0.0:
		var rev_txs: Array = state.ledger.get("transactions", [])
		var rev_tx_id := "TX_" + str(rev_txs.size()).pad_zeros(6)
		var rev_tx: Dictionary = {
			"tx_id": rev_tx_id,
			"week": week_number,
			"scenario_id": scenario_id,
			"source": "finance_week",
			"memo": "PATCH 2 revenue week " + str(week_number),
			"tags": {"mode": "ledger_patch2"},
			"journal": [
				{"gl": CASH_GL, "dc": "D", "amount": revenue_delta},
				{"gl": REV_GL, "dc": "C", "amount": revenue_delta}
			]
		}
		var rev_result: Dictionary = _ledger.post_transaction(state.ledger, rev_tx)
		if bool(rev_result.get("ok", false)):
			posted += 1
		else:
			for msg in rev_result.get("errors", []):
				errs.append(str(msg))
	elif revenue_delta < 0.0:
		errs.append("negative revenue_delta unsupported in PATCH 2 ledger posting")

	if expense_delta > 0.0:
		var exp_txs: Array = state.ledger.get("transactions", [])
		var exp_tx_id := "TX_" + str(exp_txs.size()).pad_zeros(6)
		var exp_tx: Dictionary = {
			"tx_id": exp_tx_id,
			"week": week_number,
			"scenario_id": scenario_id,
			"source": "finance_week",
			"memo": "PATCH 2 expense week " + str(week_number),
			"tags": {"mode": "ledger_patch2"},
			"journal": [
				{"gl": EXP_GL, "dc": "D", "amount": expense_delta},
				{"gl": CASH_GL, "dc": "C", "amount": expense_delta}
			]
		}
		var exp_result: Dictionary = _ledger.post_transaction(state.ledger, exp_tx)
		if bool(exp_result.get("ok", false)):
			posted += 1
		else:
			for msg in exp_result.get("errors", []):
				errs.append(str(msg))
	elif expense_delta < 0.0:
		errs.append("negative expense_delta unsupported in PATCH 2 ledger posting")

	# PATCH 2: Keep legacy aggregates synchronized for UI/month-close stability.
	state.cash = _ledger.get_gl_balance(state.ledger, CASH_GL)
	state.revenue_ytd = float(state.revenue_ytd) + revenue_delta
	state.expense_ytd = float(state.expense_ytd) + expense_delta
	state.revenue_mtd = float(state.revenue_mtd) + revenue_delta
	state.expense_mtd = float(state.expense_mtd) + expense_delta
	state.kpis["ask"] = float(state.kpis.get("ask", 0.0)) + ask_delta
	state.kpis["rpk"] = float(state.kpis.get("rpk", 0.0)) + rpk_delta

	var statements := generate_statements_from_ledger(state)
	state.meta["financial_statements"] = statements

	return {
		"ok": errs.is_empty(),
		"posted": posted,
		"errors": errs,
		"delta": delta,
		"cash": state.cash
	}

func close_month(state: Resource, month_id: int) -> Dictionary:
	# PATCH 1: Airport CFO month close uses statement output, not airline CASK/RASK/LF.
	if typeof(state.meta) == TYPE_DICTIONARY and (str(state.meta.get("module", "")) == "flightpath_airport" or str(state.meta.get("finance_mode", "delta")) == "ledger"):
		var state_gs := state as GameStateData
		if state_gs == null:
			push_warning("PATCH 1: airport ledger month close requires GameStateData; falling back to legacy close_month.")
		else:
			var statements := generate_statements_from_ledger(state_gs)
			state.meta["financial_statements"] = statements
			var income_statement: Dictionary = statements.get("income_statement", {}) as Dictionary
			var balance_sheet: Dictionary = statements.get("balance_sheet", {}) as Dictionary
			var cash_flow: Dictionary = statements.get("cash_flow", {}) as Dictionary
			var total_revenue := float(income_statement.get("total_operating_revenue", 0.0))
			var operating_surplus := float(income_statement.get("operating_surplus", 0.0))
			var interest := float(income_statement.get("interest_expense", 0.0))
			var operating_margin := operating_surplus / total_revenue if absf(total_revenue) > 0.0001 else 0.0
			var dscr := (operating_surplus + interest) / interest if interest > 0.0001 else 999.0

			var report_led: Dictionary = {
				"month": month_id,
				"cash": state.cash,
				"income_statement": income_statement,
				"balance_sheet": balance_sheet,
				"cash_flow": cash_flow,
				"kpis": {
					"cash": state.cash,
					"operating_margin": operating_margin,
					"dscr": dscr,
					"passenger_volume_mtd": float(state.kpis.get("passenger_volume_mtd", 0.0))
				}
			}

			state.meta["cash_close_anchor"] = state.cash

			state.kpis.erase("passenger_volume_mtd")
			state.kpis.erase("turnarounds_mtd")
			state.revenue_mtd = 0.0
			state.expense_mtd = 0.0

			return report_led

	var ask: float = max(float(state.kpis.get("ask", 0.0)), 1.0)
	var rpk: float = float(state.kpis.get("rpk", 0.0))

	var cask: float = float(state.expense_mtd) / ask
	var rask: float = float(state.revenue_mtd) / ask
	var lf: float = rpk / ask

	var report: Dictionary = {
		"month": month_id,
		"rev_mtd": state.revenue_mtd,
		"exp_mtd": state.expense_mtd,
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
	state.revenue_mtd = 0.0
	state.expense_mtd = 0.0

	return report

func _lease_cost_weekly(state: Resource) -> float:
	# Sum monthly lease by aircraft type, spread over 4 weeks
	var monthly: float = 0.0
	for t in state.fleet.keys():
		var a: Dictionary = state.fleet[t]
		monthly += float(a.get("lease_usd_mpm", 0.0)) * float(a.get("count", 0))
	return monthly / 4.0

func _weekly_interest_expense(debt_stack: Array) -> float:
	var total := 0.0
	for debt_value in debt_stack:
		if typeof(debt_value) != TYPE_DICTIONARY:
			continue
		var debt: Dictionary = debt_value as Dictionary
		total += float(debt.get("principal", 0.0)) * float(debt.get("rate_apr", 0.0)) / 52.0
	return total

func _post_airport_tx(
	state: GameStateData,
	week_number: int,
	scenario_id: String,
	memo: String,
	debit_gl: String,
	credit_gl: String,
	amount: float,
	errors: Array[String]
) -> int:
	if amount <= 0.0:
		return 0
	var txs: Array = state.ledger.get("transactions", [])
	var tx_id := "AIRPORT_W%s_TX_%s" % [str(week_number).pad_zeros(2), str(txs.size()).pad_zeros(6)]
	var tx: Dictionary = {
		"tx_id": tx_id,
		"week": week_number,
		"scenario_id": scenario_id,
		"source": "airport_week",
		"cash_flow_category": "operating",
		"memo": memo,
		"tags": {"mode": "flightpath_airport"},
		"journal": [
			{"gl": debit_gl, "dc": "D", "amount": amount},
			{"gl": credit_gl, "dc": "C", "amount": amount}
		]
	}
	var result: Dictionary = _ledger.post_transaction(state.ledger, tx)
	if bool(result.get("ok", false)):
		return 1
	var tx_errors: Array = result.get("errors", [])
	for msg in tx_errors:
		errors.append(str(msg))
	return 0
