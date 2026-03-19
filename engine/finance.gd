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

var _ledger := preload("res://engine/ledger.gd").new()

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
	var statements: Dictionary = _ledger.rollup_tb_to_statements(state.ledger, state.coa)
	var cash_flow: Dictionary = statements.get("cash_flow", {}) as Dictionary
	var ending_cash := float(cash_flow.get("ending_cash", _ledger.get_gl_balance(state.ledger, CASH_GL)))
	var anchor := ending_cash
	if typeof(state.meta) == TYPE_DICTIONARY and state.meta.has("cash_close_anchor"):
		anchor = float(state.meta.get("cash_close_anchor", ending_cash))
	cash_flow["ending_cash"] = ending_cash
	cash_flow["net_change_in_cash"] = ending_cash - anchor
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
	# PATCH 2: LEDGER MODE month close uses TB-derived statements, but keeps existing KPI resets.
	if typeof(state.meta) == TYPE_DICTIONARY and str(state.meta.get("finance_mode", "delta")) == "ledger":
		var state_gs := state as GameStateData
		if state_gs == null:
			push_warning("PATCH 2: ledger month close requires GameStateData; falling back to legacy close_month.")
		else:
			var ask_led: float = max(float(state.kpis.get("ask", 0.0)), 1.0)
			var rpk_led: float = float(state.kpis.get("rpk", 0.0))
			var cask_led: float = float(state.expense_mtd) / ask_led
			var rask_led: float = float(state.revenue_mtd) / ask_led
			var lf_led: float = rpk_led / ask_led
			var statements := generate_statements_from_ledger(state_gs)
			state.meta["financial_statements"] = statements

			var report_led: Dictionary = {
				"month": month_id,
				"rev_mtd": state.revenue_mtd,
				"exp_mtd": state.expense_mtd,
				"rev_ytd": state.revenue_ytd,
				"exp_ytd": state.expense_ytd,
				"cash": state.cash,
				"cask": cask_led,
				"rask": rask_led,
				"lf": lf_led,
				"statements": statements
			}

			state.meta["cash_close_anchor"] = state.cash

			# Reset rolling counters for next month aggregation (same as legacy path).
			state.kpis.erase("ask")
			state.kpis.erase("rpk")
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
