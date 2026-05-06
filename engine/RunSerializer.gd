extends RefCounted

const SCHEMA_VERSION := "1.0"

func serialize_loop_state(loop_state: LoopState) -> Dictionary:
	return {
		"version": LoopState.VERSION,
		"hq_strength": loop_state.hq_strength,
		"recruits": loop_state.recruits.duplicate(true),
		"unlocks": loop_state.unlocks.duplicate(true),
		"audit_pressure": loop_state.audit_pressure,
		"flags": loop_state.flags.duplicate(true),
		"memory": loop_state.memory.duplicate(true),
		"points": loop_state.points,
		"audit_score": loop_state.audit_score,
		"reputation": loop_state.reputation,
		"ops_risk": loop_state.ops_risk,
		"completed_missions": loop_state.completed_missions.duplicate(true),
		"mission_log": loop_state.mission_log.duplicate(true),
		"inbox": loop_state.inbox.duplicate(true),
		"week_number": loop_state.week_number,
		"month_number": loop_state.month_number
	}

func apply_loop_state(loop_state: LoopState, payload: Dictionary) -> void:
	loop_state.hq_strength = float(payload.get("hq_strength", 0.0))
	loop_state.recruits = _dict(payload, "recruits")
	loop_state.unlocks = _dict(payload, "unlocks")
	loop_state.audit_pressure = float(payload.get("audit_pressure", 0.0))
	loop_state.flags = _dict(payload, "flags")
	loop_state.memory = _dict(payload, "memory")
	loop_state.points = int(payload.get("points", 0))
	loop_state.audit_score = int(payload.get("audit_score", 0))
	loop_state.reputation = float(payload.get("reputation", 0.0))
	loop_state.ops_risk = float(payload.get("ops_risk", 0.0))
	loop_state.completed_missions = _dict(payload, "completed_missions")
	loop_state.mission_log = _array(payload, "mission_log")
	loop_state.inbox = _array(payload, "inbox")
	loop_state.week_number = int(payload.get("week_number", 0))
	loop_state.month_number = int(payload.get("month_number", 1))

func serialize_financial_state(financial_state: GameStateData) -> Dictionary:
	return {
		"version": GameStateData.VERSION,
		"cash": financial_state.cash,
		"revenue_ytd": financial_state.revenue_ytd,
		"expense_ytd": financial_state.expense_ytd,
		"revenue_mtd": financial_state.revenue_mtd,
		"expense_mtd": financial_state.expense_mtd,
		"ledger": financial_state.ledger.duplicate(true),
		"coa": financial_state.coa.duplicate(true),
		"airport": financial_state.airport.duplicate(true),
		"commercial": financial_state.commercial.duplicate(true),
		"contracts": financial_state.contracts.duplicate(true),
		"economy": financial_state.economy.duplicate(true),
		"finance": financial_state.finance.duplicate(true),
		"debt_stack": financial_state.debt_stack.duplicate(true),
		"covenants": financial_state.covenants.duplicate(true),
		"fleet": financial_state.fleet.duplicate(true),
		"routes": financial_state.routes.duplicate(true),
		"fuel": financial_state.fuel.duplicate(true),
		"kpis": financial_state.kpis.duplicate(true),
		"meta": financial_state.meta.duplicate(true)
	}

func apply_financial_state(financial_state: GameStateData, payload: Dictionary) -> void:
	financial_state.reset()
	financial_state.cash = float(payload.get("cash", 0.0))
	financial_state.revenue_ytd = float(payload.get("revenue_ytd", 0.0))
	financial_state.expense_ytd = float(payload.get("expense_ytd", 0.0))
	financial_state.revenue_mtd = float(payload.get("revenue_mtd", 0.0))
	financial_state.expense_mtd = float(payload.get("expense_mtd", 0.0))
	financial_state.ledger = _dict(payload, "ledger")
	financial_state.coa = _dict(payload, "coa")
	financial_state.airport = _dict(payload, "airport")
	financial_state.commercial = _dict(payload, "commercial")
	financial_state.contracts = _dict(payload, "contracts")
	financial_state.economy = _dict(payload, "economy")
	financial_state.finance = _dict(payload, "finance")
	financial_state.debt_stack = _array(payload, "debt_stack")
	financial_state.covenants = _dict(payload, "covenants")
	financial_state.fleet = _dict(payload, "fleet")
	financial_state.routes = _dict(payload, "routes")
	financial_state.fuel = _dict(payload, "fuel")
	financial_state.kpis = _dict(payload, "kpis")
	financial_state.meta = _dict(payload, "meta")

func build_export_markdown(snapshot: Dictionary) -> String:
	var loop: Dictionary = snapshot.get("loop", {}) as Dictionary
	var financial: Dictionary = snapshot.get("financial", {}) as Dictionary
	var ledger: Dictionary = snapshot.get("ledger", {}) as Dictionary
	var objectives: Dictionary = snapshot.get("objectives", {}) as Dictionary
	var contract_reviews: Dictionary = snapshot.get("contract_reviews", {}) as Dictionary
	var remediation: Dictionary = snapshot.get("audit_room_remediation", {}) as Dictionary
	var balance_sheet: Dictionary = financial.get("balance_sheet", {}) as Dictionary

	var lines: Array[String] = []
	lines.append("# Redline Simulator: Flightpath CFO - Run Summary")
	lines.append("")
	lines.append("Generated: %s" % Time.get_datetime_string_from_system(true, true))
	lines.append("")
	lines.append("## Current Position")
	lines.append("- Week: %d" % int(loop.get("week_number", loop.get("week", 0))))
	lines.append("- Month: %d" % int(loop.get("month_number", loop.get("month", 1))))
	lines.append("- Cash: %s" % _format_currency(float(balance_sheet.get("cash", financial.get("cash", 0.0)))))
	lines.append("- Total Debt: %s" % _format_currency(_extract_total_debt(balance_sheet)))
	lines.append("- Points: %d" % int(loop.get("points", 0)))
	lines.append("- Audit Score: %d" % int(loop.get("audit_score", 0)))
	lines.append("- Ops Risk: %s" % _format_number(float(loop.get("ops_risk", 0.0))))
	lines.append("- Reputation: %s" % _format_number(float(loop.get("reputation", 0.0))))
	lines.append("")
	lines.append("## Financial Snapshot")
	lines.append("- Operating Margin: %s" % _format_percent(float((financial.get("kpis", {}) as Dictionary).get("operating_margin", 0.0))))
	lines.append("- DSCR: %s" % _format_number(float((financial.get("kpis", {}) as Dictionary).get("dscr", 0.0))))
	lines.append("")
	lines.append("## Objectives")
	if objectives.is_empty():
		lines.append("- None evaluated.")
	else:
		for key in objectives.keys():
			var result: Dictionary = objectives.get(key, {}) as Dictionary
			lines.append("- %s: %s | actual %s | target %s | %s" % [
				str(result.get("id", key)),
				"PASSED" if bool(result.get("passed", false)) else "MISSED",
				_format_number(float(result.get("actual", 0.0))),
				_format_number(float(result.get("target", 0.0))),
				str(result.get("message", ""))
			])
	lines.append("")
	lines.append("## Contract Reviews")
	if contract_reviews.is_empty():
		lines.append("- None.")
	else:
		for key in contract_reviews.keys():
			var review: Dictionary = contract_reviews.get(key, {}) as Dictionary
			lines.append("- %s: status `%s`, risk `%s`, clawback `%s`, service commitment `%s`" % [
				str(key),
				str(review.get("status", "unknown")),
				str(review.get("risk_rating", "unknown")),
				str(review.get("clawback_strength", "unknown")),
				"yes" if bool(review.get("minimum_service_commitment", false)) else "no"
			])
	lines.append("")
	lines.append("## Audit Room Remediation")
	if remediation.is_empty():
		lines.append("- None.")
	else:
		lines.append("- %s: %s" % [
			str(remediation.get("remediation_id", "remediation")),
			str(remediation.get("feedback", ""))
		])
	lines.append("")
	lines.append("## Ledger Trail")
	var recent_value: Variant = ledger.get("recent_transactions", [])
	var recent: Array = []
	if typeof(recent_value) == TYPE_ARRAY:
		recent = recent_value as Array
	if recent.is_empty():
		lines.append("- No recent transactions.")
	else:
		for tx_value in recent:
			if typeof(tx_value) != TYPE_DICTIONARY:
				continue
			var tx: Dictionary = tx_value as Dictionary
			lines.append("- `%s` | %s | week %s | %s" % [
				str(tx.get("tx_id", "tx")),
				str(tx.get("source", "ledger")),
				str(tx.get("week", "-")),
				str(tx.get("memo", ""))
			])
	lines.append("")
	lines.append("## Trial Balance")
	var tb: Dictionary = ledger.get("trial_balance", {}) as Dictionary
	if tb.is_empty():
		lines.append("- Empty.")
	else:
		for gl in tb.keys():
			lines.append("- `%s`: %s" % [str(gl), _format_number(float(tb.get(gl, 0.0)))])
	lines.append("")
	lines.append("## Notes")
	lines.append("Ledger is the source of truth. This export is for review and teaching discussion.")
	return "\n".join(PackedStringArray(lines))

func _dict(payload: Dictionary, key: String) -> Dictionary:
	var value: Variant = payload.get(key, {})
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}

func _array(payload: Dictionary, key: String) -> Array:
	var value: Variant = payload.get(key, [])
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []

func _extract_total_debt(balance_sheet: Dictionary) -> float:
	if balance_sheet.has("total_debt"):
		return float(balance_sheet.get("total_debt", 0.0))
	return float(balance_sheet.get("short_term_debt", 0.0)) + float(balance_sheet.get("debt_term_loan", 0.0))

func _format_currency(value: float) -> String:
	return "$" + _format_int_with_commas(int(round(value)))

func _format_int_with_commas(value: int) -> String:
	var sign := ""
	var n := value
	if n < 0:
		sign = "-"
		n = -n
	var digits := str(n)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3, 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return sign + digits + out

func _format_percent(value: float) -> String:
	return "%.1f%%" % (value * 100.0)

func _format_number(value: float) -> String:
	if absf(value - round(value)) < 0.001:
		return str(int(round(value)))
	return "%.2f" % value
