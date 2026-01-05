# res://engine/DecisionResolver.gd
extends Node

signal decision_applied(tag: String, impacts: Dictionary)
signal week_advanced(week_number: int, month_number: int, is_month_end: bool)
signal month_end_ready(month_number: int, report: Dictionary)

const LEGACY_WEEKLY_OPEX_USD := 5000.0

var _loop_system: Node = null
var _financial_state: GameStateData = preload("res://engine/state.gd").new()
var _finance := preload("res://engine/finance.gd").new()
var _last_month_report: Dictionary = {}

func _ready() -> void:
	_loop_system = get_node_or_null("/root/LoopSystem")
	if _loop_system == null:
		push_warning("LoopSystem autoload missing; loop state will not advance.")

func load_scenario(cfg: Dictionary) -> void:
	_financial_state.reset()
	_financial_state.load_config(cfg.get("initial_state", {}))
	if _loop_system:
		_loop_system.call("reset")

func seed_financial_state(cfg: Dictionary, reset: bool = true) -> void:
	if reset:
		_financial_state.reset()
	_financial_state.load_config(cfg)

func get_financial_state_ref() -> GameStateData:
	# Exposed read-only by convention.
	return _financial_state

func get_financial_snapshot() -> Dictionary:
	return _financial_state.get_financial_summary()

func get_loop_snapshot() -> Dictionary:
	if _loop_system:
		return _loop_system.call("get_snapshot") as Dictionary
	return {}

func get_last_month_report() -> Dictionary:
	return _last_month_report

func advance_week(use_legacy_burn: bool = true) -> Dictionary:
	var impacts: Dictionary = {}
	if use_legacy_burn:
		impacts["financial"] = _apply_weekly_burn(LEGACY_WEEKLY_OPEX_USD)
	else:
		impacts["financial"] = _apply_weekly_finance()

	var turn_info: Dictionary = _advance_loop_time()
	var month_report: Dictionary = {}
	emit_signal("week_advanced", turn_info["week_number"], turn_info["month_number"], turn_info["is_month_end"])
	if turn_info["is_month_end"]:
		month_report = _last_month_report
		emit_signal("month_end_ready", turn_info["closed_month"], month_report)

	return {
		"turn": turn_info,
		"impacts": impacts,
		"month_report": month_report
	}

func resolve_intent(intent: Dictionary) -> Dictionary:
	var impacts: Dictionary = {}
	var tag := str(intent.get("tag", "intent"))

	if intent.has("financial_delta"):
		impacts["financial"] = _apply_financial_delta(intent["financial_delta"])

	if intent.has("loop_delta"):
		impacts["loop"] = _apply_loop_delta(intent["loop_delta"])

	emit_signal("decision_applied", tag, impacts)
	return impacts

func _advance_loop_time() -> Dictionary:
	if _loop_system == null:
		return {
			"week_number": 0,
			"month_number": 0,
			"week_in_month": 0,
			"is_month_end": false,
			"closed_month": 0
		}

	var state: LoopState = _loop_system.call("get_state_ref") as LoopState
	state.week_number += 1

	var is_month_end := (state.week_number % 4) == 0
	var closed_month := state.month_number
	if is_month_end:
		_last_month_report = _finance.close_month(_financial_state, closed_month)
		state.month_number += 1

	_loop_system.call("notify_updated")

	return {
		"week_number": state.week_number,
		"month_number": state.month_number,
		"week_in_month": ((state.week_number - 1) % 4) + 1 if state.week_number > 0 else 0,
		"is_month_end": is_month_end,
		"closed_month": closed_month
	}

func _apply_weekly_burn(weekly_opex: float) -> Dictionary:
	_financial_state.cash -= weekly_opex
	_financial_state.expense_ytd += weekly_opex
	return {
		"cash_delta": -weekly_opex,
		"expense_delta": weekly_opex
	}

func _apply_weekly_finance() -> Dictionary:
	var delta := _finance.calculate_week_delta(_financial_state)
	return _apply_financial_delta(delta)

func _apply_financial_delta(delta: Dictionary) -> Dictionary:
	var cash_delta := float(delta.get("cash_delta", 0.0))
	var revenue_delta := float(delta.get("revenue_delta", 0.0))
	var expense_delta := float(delta.get("expense_delta", 0.0))
	var ask_delta := float(delta.get("ask_delta", 0.0))
	var rpk_delta := float(delta.get("rpk_delta", 0.0))

	_financial_state.cash = float(_financial_state.cash) + cash_delta
	_financial_state.revenue_ytd = float(_financial_state.revenue_ytd) + revenue_delta
	_financial_state.expense_ytd = float(_financial_state.expense_ytd) + expense_delta
	_financial_state.kpis["ask"] = float(_financial_state.kpis.get("ask", 0.0)) + ask_delta
	_financial_state.kpis["rpk"] = float(_financial_state.kpis.get("rpk", 0.0)) + rpk_delta

	return {
		"cash_delta": cash_delta,
		"revenue_delta": revenue_delta,
		"expense_delta": expense_delta,
		"ask_delta": ask_delta,
		"rpk_delta": rpk_delta
	}

func _apply_loop_delta(delta: Dictionary) -> Dictionary:
	if _loop_system == null:
		return {}

	var state: LoopState = _loop_system.call("get_state_ref") as LoopState

	if delta.has("hq_strength_delta"):
		state.hq_strength += float(delta["hq_strength_delta"])
	if delta.has("audit_pressure_delta"):
		state.audit_pressure += float(delta["audit_pressure_delta"])

	if delta.has("recruits_add"):
		for key in delta["recruits_add"].keys():
			state.recruits[key] = delta["recruits_add"][key]

	if delta.has("unlocks_add"):
		for key in delta["unlocks_add"].keys():
			state.unlocks[key] = delta["unlocks_add"][key]

	if delta.has("flags_set"):
		for key in delta["flags_set"].keys():
			state.flags[key] = delta["flags_set"][key]

	if delta.has("memory_set"):
		for key in delta["memory_set"].keys():
			state.memory[key] = delta["memory_set"][key]

	_loop_system.call("notify_updated")

	return {
		"hq_strength": state.hq_strength,
		"audit_pressure": state.audit_pressure,
		"recruits": state.recruits,
		"unlocks": state.unlocks,
		"flags": state.flags,
		"memory": state.memory
	}
