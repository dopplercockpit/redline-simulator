extends RefCounted

const SCHEMA_VERSION := "1.0"
const LedgerUtil = preload("res://engine/ledger.gd")

var _ledger := LedgerUtil.new()

func build_demo_state(target: String, scenario: Dictionary) -> Dictionary:
	var normalized_target := target.strip_edges().to_lower()
	if normalized_target == "":
		normalized_target = "fresh_start"

	var initial_state: Dictionary = scenario.get("initial_state", {}) as Dictionary
	var finance: Dictionary = initial_state.get("finance", {}) as Dictionary
	var opening_balances: Dictionary = finance.get("opening_balances", {}) as Dictionary
	var ledger_state := _ledger.new_ledger_state()
	_ledger.seed_opening_balances(ledger_state, opening_balances)
	var txs := _demo_transactions_for(normalized_target)
	for tx in txs:
		_post_demo_transaction(ledger_state, tx)

	var financial_state := _base_financial_state(initial_state, ledger_state)
	var loop_state := _base_loop_state(normalized_target)
	_apply_target_loop(loop_state, normalized_target)
	_apply_target_financial(financial_state, normalized_target)
	_sync_cash_from_ledger(financial_state)

	return {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"scenario": scenario.duplicate(true),
		"objectives_evaluated": (loop_state.get("memory", {}) as Dictionary).get("objective_results", {}).duplicate(true),
		"loop_state": loop_state,
		"financial_state": financial_state
	}

func _base_financial_state(initial_state: Dictionary, ledger_state: Dictionary) -> Dictionary:
	var finance: Dictionary = initial_state.get("finance", {}) as Dictionary
	var coa_ref := str(finance.get("coa_ref", "res://data/finance/coa_airport_v1.json"))
	var coa := _ledger.load_coa(coa_ref)
	var debt_stack: Array = finance.get("debt_stack", []) as Array
	var covenants: Dictionary = {}
	if not debt_stack.is_empty() and typeof(debt_stack[0]) == TYPE_DICTIONARY:
		covenants = (debt_stack[0] as Dictionary).get("covenants", {}) as Dictionary
	return {
		"version": GameStateData.VERSION,
		"cash": float((ledger_state.get("trial_balance", {}) as Dictionary).get("1000", 0.0)),
		"revenue_ytd": 0.0,
		"expense_ytd": 0.0,
		"revenue_mtd": 0.0,
		"expense_mtd": 0.0,
		"ledger": ledger_state.duplicate(true),
		"coa": coa.duplicate(true),
		"airport": (initial_state.get("airport", {}) as Dictionary).duplicate(true),
		"commercial": (initial_state.get("commercial", {}) as Dictionary).duplicate(true),
		"contracts": (initial_state.get("contracts", {}) as Dictionary).duplicate(true),
		"economy": (initial_state.get("economy", {}) as Dictionary).duplicate(true),
		"finance": finance.duplicate(true),
		"debt_stack": debt_stack.duplicate(true),
		"covenants": covenants.duplicate(true),
		"fleet": {},
		"routes": {},
		"fuel": {"price_usd_per_ton": 830.0, "hedge_pct": 0.2, "hedge_price": 700.0},
		"kpis": {},
		"meta": {
			"module": "flightpath_airport",
			"finance_mode": "ledger",
			"coa_ref": coa_ref
		}
	}

func _base_loop_state(target: String) -> Dictionary:
	return {
		"version": LoopState.VERSION,
		"hq_strength": 0.0,
		"recruits": {},
		"unlocks": {},
		"audit_pressure": 0.0,
		"flags": {"demo_mode": true},
		"memory": {"demo_target": target},
		"points": 0,
		"audit_score": 0,
		"reputation": 0.0,
		"ops_risk": 0.0,
		"completed_missions": {},
		"mission_log": [],
		"inbox": [],
		"week_number": 0,
		"month_number": 1
	}

func _apply_target_loop(loop_state: Dictionary, target: String) -> void:
	var flags: Dictionary = loop_state.get("flags", {}) as Dictionary
	var memory: Dictionary = loop_state.get("memory", {}) as Dictionary
	var unlocks: Dictionary = loop_state.get("unlocks", {}) as Dictionary
	var completed: Dictionary = loop_state.get("completed_missions", {}) as Dictionary
	var objectives: Dictionary = {}

	if target in ["month1_complete", "month2_complete", "month3_complete", "full_demo_complete"]:
		loop_state["week_number"] = 4
		loop_state["month_number"] = 2
		loop_state["points"] = 190
		loop_state["audit_score"] = 4
		loop_state["reputation"] = -1.0
		loop_state["ops_risk"] = 1.0
		unlocks["DEBT_DESK"] = true
		completed["MISSION_MONTH_CLOSE_V1_M1"] = true
		objectives["obj_cash"] = _objective("obj_cash", true, "cash", 1040000.0, 900000.0, "Cash objective met. Debt Desk unlocked.", 150, ["DEBT_DESK"])
		flags["objective_completed.obj_cash"] = true
		flags["objective_checked.obj_cash"] = true

	if target in ["month2_complete", "month3_complete", "full_demo_complete"]:
		loop_state["week_number"] = 8
		loop_state["month_number"] = 3
		loop_state["points"] = 430
		loop_state["audit_score"] = 8
		loop_state["reputation"] = 0.0
		loop_state["ops_risk"] = 4.0
		unlocks["CONTRACT_REVIEW"] = true
		completed["MISSION_MONTH_CLOSE_ROUTE_INCENTIVE_V1_M2"] = true
		objectives["obj_route_incentive"] = _objective("obj_route_incentive", true, "operating_margin", 0.12, 0.05, "Route incentive economics held above the operating margin threshold. Contract Review unlocked.", 200, ["CONTRACT_REVIEW"])
		objectives["obj_cash_month2"] = _objective("obj_cash_month2", true, "cash", 910000.0, 750000.0, "Month 2 cash floor held. Liquidity survived the growth experiment.", 100, [])
		flags["objective_completed.obj_route_incentive"] = true
		flags["objective_checked.obj_route_incentive"] = true
		flags["objective_completed.obj_cash_month2"] = true
		flags["objective_checked.obj_cash_month2"] = true

	if target in ["month3_complete", "full_demo_complete"]:
		loop_state["week_number"] = 12
		loop_state["month_number"] = 4
		loop_state["points"] = 720
		loop_state["audit_score"] = 12
		loop_state["reputation"] = 1.0
		loop_state["ops_risk"] = 5.0
		unlocks["AUDIT_ROOM"] = true
		completed["MISSION_MONTH_CLOSE_COMPLIANCE_V1_M3"] = true
		objectives["obj_audit_month3"] = _objective("obj_audit_month3", true, "audit_score", 12.0, 18.0, "Audit posture held within tolerance. Audit Room unlocked.", 150, ["AUDIT_ROOM"])
		objectives["obj_ops_risk_month3"] = _objective("obj_ops_risk_month3", true, "ops_risk", 5.0, 8.0, "Operational risk stayed controlled through the compliance cycle.", 100, [])
		objectives["obj_cash_month3"] = _objective("obj_cash_month3", true, "cash", 830000.0, 650000.0, "Month 3 cash floor held despite governance and compliance costs.", 100, [])
		flags["objective_completed.obj_audit_month3"] = true
		flags["objective_checked.obj_audit_month3"] = true
		flags["objective_completed.obj_ops_risk_month3"] = true
		flags["objective_checked.obj_ops_risk_month3"] = true
		flags["objective_completed.obj_cash_month3"] = true
		flags["objective_checked.obj_cash_month3"] = true
		flags["contract_review_completed.BUDGETAIR_INCENTIVE_REVIEW"] = true
		memory["contract_reviews"] = {
			"BUDGETAIR_INCENTIVE_REVIEW": {
				"review_id": "BUDGETAIR_INCENTIVE_REVIEW",
				"choice_id": "ADD_CLAWBACK_AND_SERVICE_COMMITMENT",
				"status": "approved_with_controls",
				"risk_rating": "low",
				"clawback_strength": "strong",
				"minimum_service_commitment": true,
				"week": 9,
				"feedback": "Demo fixture: strong clawback and service commitment approved."
			}
		}

	if target == "full_demo_complete":
		flags["tool_used.AUDIT_ROOM"] = true
		memory["audit_room_remediation"] = {
			"remediation_id": "CONTROL_EVIDENCE_CLEANUP",
			"label": "Fund control evidence cleanup",
			"week": 13,
			"feedback": "Demo fixture: control evidence cleanup completed."
		}
		memory["last_audit_room_feedback"] = "Demo fixture: control evidence cleanup completed."

	memory["objective_results"] = objectives
	loop_state["flags"] = flags
	loop_state["memory"] = memory
	loop_state["unlocks"] = unlocks
	loop_state["completed_missions"] = completed

func _apply_target_financial(financial_state: Dictionary, target: String) -> void:
	if target in ["month2_complete", "month3_complete", "full_demo_complete"]:
		var debt_stack: Array = financial_state.get("debt_stack", []) as Array
		debt_stack.append({
			"debt_id": "REVOLVER_DRAW_001",
			"label": "Emergency Revolver Draw",
			"principal": 250000,
			"rate_apr": 0.095,
			"amort_type": "interest_only",
			"term_months": 12,
			"type": "short_term_revolver"
		})
		financial_state["debt_stack"] = debt_stack
		var finance: Dictionary = financial_state.get("finance", {}) as Dictionary
		finance["debt_stack"] = debt_stack.duplicate(true)
		financial_state["finance"] = finance
	if target in ["month3_complete", "full_demo_complete"]:
		var contracts: Dictionary = financial_state.get("contracts", {}) as Dictionary
		contracts["active"] = [{
			"review_id": "BUDGETAIR_INCENTIVE_REVIEW",
			"choice_id": "ADD_CLAWBACK_AND_SERVICE_COMMITMENT",
			"status": "approved_with_controls",
			"risk_rating": "low",
			"clawback_strength": "strong",
			"minimum_service_commitment": true,
			"week": 9
		}]
		financial_state["contracts"] = contracts

func _demo_transactions_for(target: String) -> Array:
	var txs: Array = []
	if target in ["month1_complete", "month2_complete", "month3_complete", "full_demo_complete"]:
		txs.append(_tx("DEMO_COLLECT_AR", 1, "action_card", "Demo receivables collection", "operating", [
			{"gl": "1000", "dc": "D", "amount": 125000},
			{"gl": "1200", "dc": "C", "amount": 125000}
		]))
		txs.append(_tx("DEMO_PAY_VENDOR", 2, "action_card", "Demo critical vendor payment", "operating", [
			{"gl": "2000", "dc": "D", "amount": 90000},
			{"gl": "1000", "dc": "C", "amount": 90000}
		]))
		txs.append(_tx("DEMO_MONTH1_REVENUE", 4, "weekly_finance", "Demo Month 1 operating revenue", "operating", [
			{"gl": "1000", "dc": "D", "amount": 180000},
			{"gl": "4000", "dc": "C", "amount": 180000}
		]))
	if target in ["month2_complete", "month3_complete", "full_demo_complete"]:
		txs.append(_tx("DEMO_REVOLVER_DRAW", 5, "debt_desk", "Demo emergency revolver draw", "financing", [
			{"gl": "1000", "dc": "D", "amount": 250000},
			{"gl": "2300", "dc": "C", "amount": 250000}
		]))
		txs.append(_tx("DEMO_ROUTE_INCENTIVE", 5, "action_card", "Demo measured BudgetAir route incentive", "operating", [
			{"gl": "5200", "dc": "D", "amount": 65000},
			{"gl": "1000", "dc": "C", "amount": 65000}
		]))
		txs.append(_tx("DEMO_ROUTE_REVENUE", 8, "weekly_finance", "Demo Month 2 route revenue", "operating", [
			{"gl": "1000", "dc": "D", "amount": 260000},
			{"gl": "4200", "dc": "C", "amount": 260000}
		]))
	if target in ["month3_complete", "full_demo_complete"]:
		txs.append(_tx("DEMO_CONTRACT_REVIEW", 9, "contract_review", "Demo contract controls review", "operating", [
			{"gl": "5300", "dc": "D", "amount": 25000},
			{"gl": "1000", "dc": "C", "amount": 25000}
		]))
		txs.append(_tx("DEMO_CLAWBACK", 9, "action_card", "Demo BudgetAir clawback recovery", "operating", [
			{"gl": "1000", "dc": "D", "amount": 35000},
			{"gl": "4300", "dc": "C", "amount": 35000}
		]))
		txs.append(_tx("DEMO_COMPLIANCE_CLEANUP", 10, "action_card", "Demo compliance cleanup support", "operating", [
			{"gl": "5300", "dc": "D", "amount": 40000},
			{"gl": "1000", "dc": "C", "amount": 40000}
		]))
	if target == "full_demo_complete":
		txs.append(_tx("DEMO_AUDIT_REMEDIATION", 13, "audit_room", "Demo audit control evidence cleanup", "operating", [
			{"gl": "5300", "dc": "D", "amount": 35000},
			{"gl": "1000", "dc": "C", "amount": 35000}
		]))
	return txs

func _post_demo_transaction(ledger_state: Dictionary, tx: Dictionary) -> void:
	var transactions: Array = ledger_state.get("transactions", []) as Array
	transactions.append(tx.duplicate(true))
	ledger_state["transactions"] = transactions
	var tb: Dictionary = ledger_state.get("trial_balance", {}) as Dictionary
	_apply_demo_tx_to_trial_balance(tb, tx.get("journal", []) as Array)
	ledger_state["trial_balance"] = tb

func _apply_demo_tx_to_trial_balance(tb: Dictionary, journal: Array) -> void:
	for line_value in journal:
		if typeof(line_value) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = line_value as Dictionary
		var gl := str(line.get("gl", ""))
		var amount := float(line.get("amount", 0.0))
		var signed := amount if str(line.get("dc", "")) == "D" else -amount
		tb[gl] = float(tb.get(gl, 0.0)) + signed

func _sync_cash_from_ledger(financial_state: Dictionary) -> void:
	var ledger_state: Dictionary = financial_state.get("ledger", {}) as Dictionary
	var tb: Dictionary = ledger_state.get("trial_balance", {}) as Dictionary
	financial_state["cash"] = float(tb.get("1000", 0.0))

func _tx(tx_id: String, week: int, source: String, memo: String, cash_flow_category: String, journal: Array) -> Dictionary:
	return {
		"tx_id": tx_id,
		"week": week,
		"source": source,
		"memo": memo,
		"cash_flow_category": cash_flow_category,
		"journal": journal
	}

func _objective(id: String, passed: bool, metric: String, actual: float, target: float, message: String, points: int, unlocks: Array) -> Dictionary:
	return {
		"id": id,
		"passed": passed,
		"message": message,
		"points_awarded": points,
		"unlocks": unlocks,
		"metric": metric,
		"actual": actual,
		"target": target,
		"operator": ">=" if metric == "cash" or metric == "operating_margin" else "<="
	}
