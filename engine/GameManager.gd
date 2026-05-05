# res://engine/GameManager.gd
extends Node

signal turn_advanced(new_week: int, new_month: int)
signal month_end_ready(month_number: int, report: Dictionary)
signal mission_triggered(mission_id: String)
signal state_updated()
signal scorecard_ready(scorecard: Dictionary)

const DEFAULT_SCENARIO_PATH := "res://data/scenarios/flightpath/scenario_001.json"
const DecisionIntent = preload("res://engine/DecisionIntent.gd")

var _resolver: Node = null
var _current_scenario_config: Dictionary = {}
var _objectives_evaluated: Dictionary = {}
var _mission_manager_connected: bool = false

func _ready() -> void:
	_resolver = get_node_or_null("/root/DecisionResolver")
	if _resolver == null:
		push_warning("DecisionResolver autoload missing; GameManager is inactive.")

	_connect_mission_manager()
	call_deferred("_connect_mission_manager")

func _connect_mission_manager() -> void:
	if _mission_manager_connected:
		return
	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager:
		var loop_system := get_node_or_null("/root/LoopSystem")
		if loop_system and loop_system.has_method("get_state_ref"):
			mission_manager.call("init_from_state", loop_system.call("get_state_ref"))
		if not month_end_ready.is_connected(_on_month_end_ready):
			month_end_ready.connect(_on_month_end_ready)
		if mission_manager.has_signal("mission_completed") and not mission_manager.mission_completed.is_connected(_on_mission_completed):
			mission_manager.mission_completed.connect(_on_mission_completed)
		_mission_manager_connected = true

func load_scenario(path: String = DEFAULT_SCENARIO_PATH) -> void:
	var cfg := _read_json(path)
	if cfg.is_empty():
		return
	load_scenario_config(cfg)

func load_scenario_config(cfg: Dictionary) -> void:
	_current_scenario_config = cfg.duplicate(true)
	_objectives_evaluated = {}
	if _resolver:
		_resolver.call("load_scenario", cfg)
	emit_signal("state_updated")

func advance_week(use_legacy_burn: bool = false) -> Dictionary:
	if _resolver == null:
		return {}

	var result: Dictionary = _resolver.call("advance_week", use_legacy_burn) as Dictionary
	var turn: Dictionary = result.get("turn", {}) as Dictionary

	emit_signal("turn_advanced", int(turn.get("week_number", 0)), int(turn.get("month_number", 0)))

	if bool(turn.get("is_month_end", false)):
		var closed_month: int = int(turn.get("closed_month", 0))
		var report: Dictionary = result.get("month_report", {}) as Dictionary
		emit_signal("month_end_ready", closed_month, report)
		emit_signal("mission_triggered", "month_end_close_" + str(closed_month))

	emit_signal("state_updated")
	return result

func get_current_week() -> int:
	var loop_state := get_loop_state_ref()
	if loop_state == null:
		return 1
	return int(loop_state.week_number) + 1

func get_loop_state_ref() -> LoopState:
	var loop_system := get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_state_ref"):
		return loop_system.call("get_state_ref") as LoopState
	return null

func submit_action_card_choice(card_id: String, choice_id: String, choice: Dictionary) -> Dictionary:
	var scene_path := ""
	if get_tree() and get_tree().current_scene:
		scene_path = str(get_tree().current_scene.scene_file_path)
	var intent: Dictionary = DecisionIntent.build_intent(
		"action_card_choice.%s.%s" % [card_id, choice_id],
		DecisionIntent.VERB_USE,
		"action_card",
		scene_path,
		str(get_path())
	)
	intent["action_card_choice"] = {
		"card_id": card_id,
		"choice_id": choice_id,
		"choice": choice
	}
	return submit_intent(intent)

func submit_debt_desk_choice(offer_id: String, offer: Dictionary) -> Dictionary:
	var scene_path := ""
	if get_tree() and get_tree().current_scene:
		scene_path = str(get_tree().current_scene.scene_file_path)
	var intent: Dictionary = DecisionIntent.build_intent(
		"debt_desk_choice.%s" % offer_id,
		DecisionIntent.VERB_USE,
		"debt_desk",
		scene_path,
		str(get_path())
	)
	intent["debt_desk_choice"] = {
		"offer_id": offer_id,
		"offer": offer
	}
	return submit_intent(intent)

func is_debt_desk_unlocked() -> bool:
	var loop_state := get_loop_state_ref()
	if loop_state == null:
		return false
	return bool(loop_state.unlocks.get("DEBT_DESK", false))

func is_debt_desk_used() -> bool:
	var loop_state := get_loop_state_ref()
	if loop_state == null:
		return false
	return bool(loop_state.flags.get("tool_used.DEBT_DESK", false))

func submit_intent(intent: Dictionary) -> Dictionary:
	if _resolver == null:
		return {}
	var result: Dictionary = _resolver.call("resolve_intent", intent) as Dictionary
	if bool(result.get("ok", false)):
		emit_signal("state_updated")
	return result

func get_financial_state_ref() -> GameStateData:
	if _resolver:
		return _resolver.call("get_financial_state_ref") as GameStateData
	return null

func get_financial_snapshot() -> Dictionary:
	if _resolver:
		return _resolver.call("get_financial_snapshot") as Dictionary
	return {}

func get_loop_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	if _resolver:
		snap = _resolver.call("get_loop_snapshot") as Dictionary
	else:
		var loop_system := get_node_or_null("/root/LoopSystem")
		if loop_system and loop_system.has_method("get_snapshot"):
			snap = loop_system.call("get_snapshot") as Dictionary
	if snap.has("week_number") and not snap.has("week"):
		snap["week"] = snap.get("week_number")
	if snap.has("month_number") and not snap.has("month"):
		snap["month"] = snap.get("month_number")
	return snap

func evaluate_objectives(context: Dictionary = {}) -> Dictionary:
	var loop_state := get_loop_state_ref()
	if loop_state == null:
		return {"results": [], "errors": ["LoopState unavailable"]}

	var objectives_value: Variant = _current_scenario_config.get("objectives", [])
	if typeof(objectives_value) != TYPE_ARRAY:
		return {"results": [], "errors": ["Scenario objectives must be an Array"]}

	var objectives: Array = objectives_value as Array
	var results: Array = []
	var current_week := int(loop_state.week_number)
	var financial_snapshot := get_financial_snapshot()
	var last_month_report := _get_last_month_report()

	for objective_value in objectives:
		if typeof(objective_value) != TYPE_DICTIONARY:
			continue
		var objective: Dictionary = objective_value as Dictionary
		var objective_id := str(objective.get("id", "objective"))
		var by_week := int(objective.get("by_week", 0))
		if by_week > 0 and current_week < by_week:
			continue

		var stored_results: Dictionary = loop_state.memory.get("objective_results", {}) as Dictionary
		var checked_flag := "objective_checked.%s" % objective_id
		if bool(loop_state.flags.get(checked_flag, false)) and stored_results.has(objective_id):
			results.append(stored_results.get(objective_id))
			continue

		var metric := str(objective.get("metric", ""))
		var actual := _get_objective_metric(metric, loop_state, financial_snapshot, last_month_report, context)
		var target := float(objective.get("value", 0.0))
		var operator := str(objective.get("operator", ">="))
		var passed := _compare_metric(actual, operator, target)

		var reward: Dictionary = objective.get("reward", {}) as Dictionary
		var points_awarded := 0
		var unlocks_awarded: Array[String] = []
		var message := ""
		if passed:
			var completed_flag := "objective_completed.%s" % objective_id
			if not bool(loop_state.flags.get(completed_flag, false)):
				points_awarded = int(reward.get("points", 0))
				loop_state.points += points_awarded
				var unlocks_add: Dictionary = reward.get("unlocks_add", {}) as Dictionary
				for unlock_key in unlocks_add.keys():
					if bool(unlocks_add.get(unlock_key, false)):
						loop_state.unlocks[str(unlock_key)] = true
						unlocks_awarded.append(str(unlock_key))
				var flags_set: Dictionary = reward.get("flags_set", {}) as Dictionary
				for flag_key in flags_set.keys():
					loop_state.flags[str(flag_key)] = flags_set.get(flag_key)
				loop_state.flags[completed_flag] = true
			message = _objective_success_message(objective_id, unlocks_awarded)
		else:
			message = _objective_failure_message(objective_id)

		loop_state.flags[checked_flag] = true
		var result := {
			"id": objective_id,
			"passed": passed,
			"message": message,
			"points_awarded": points_awarded,
			"unlocks": unlocks_awarded,
			"metric": metric,
			"actual": actual,
			"target": target,
			"operator": operator
		}
		stored_results[objective_id] = result
		_objectives_evaluated[objective_id] = result
		loop_state.memory["objective_results"] = stored_results
		results.append(result)

	var loop_system := get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("notify_updated"):
		loop_system.call("notify_updated")

	return {
		"results": results,
		"errors": []
	}

func build_month_scorecard(objective_results: Array = []) -> Dictionary:
	var loop_snapshot := get_loop_snapshot()
	var financial_snapshot := get_financial_snapshot()
	var last_month_report := _get_last_month_report()
	var balance_sheet: Dictionary = financial_snapshot.get("balance_sheet", {}) as Dictionary
	var kpis: Dictionary = last_month_report.get("kpis", {}) as Dictionary
	var financial_kpis: Dictionary = financial_snapshot.get("kpis", {}) as Dictionary

	var cash := float(balance_sheet.get("cash", financial_snapshot.get("cash", 0.0)))
	var total_debt := float(balance_sheet.get(
		"total_debt",
		float(balance_sheet.get("short_term_debt", 0.0)) + float(balance_sheet.get("debt_term_loan", 0.0))
	))
	var operating_margin := float(kpis.get("operating_margin", financial_kpis.get("operating_margin", 0.0)))
	var dscr := float(kpis.get("dscr", financial_kpis.get("dscr", 0.0)))
	var unlocks: Dictionary = loop_snapshot.get("unlocks", {}) as Dictionary
	var completed_missions_dict: Dictionary = loop_snapshot.get("completed_missions", {}) as Dictionary
	var completed_missions: Array[String] = []
	for mission_id in completed_missions_dict.keys():
		if bool(completed_missions_dict.get(mission_id, false)):
			completed_missions.append(str(mission_id))

	var month := int(last_month_report.get("month", max(1, int(loop_snapshot.get("month_number", 1)) - 1)))
	return {
		"title": "Month %d Scorecard" % month,
		"month": month,
		"cash": cash,
		"total_debt": total_debt,
		"operating_margin": operating_margin,
		"dscr": dscr,
		"points": int(loop_snapshot.get("points", 0)),
		"audit_score": int(loop_snapshot.get("audit_score", 0)),
		"reputation": float(loop_snapshot.get("reputation", 0.0)),
		"ops_risk": float(loop_snapshot.get("ops_risk", 0.0)),
		"completed_missions": completed_missions,
		"unlocks": unlocks.duplicate(true),
		"objective_results": objective_results
	}

func _on_month_end_ready(month_number: int, report: Dictionary) -> void:
	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager == null:
		return
	var loop_snapshot := get_loop_snapshot()
	loop_snapshot["closed_month"] = month_number
	mission_manager.call("enqueue_month_close", report, loop_snapshot)

func _on_mission_completed(result: Dictionary) -> void:
	var mission_id := str(result.get("mission_id", ""))
	if not mission_id.contains("MISSION_MONTH_CLOSE"):
		emit_signal("state_updated")
		return

	var objective_result_payload := evaluate_objectives()
	var objective_results: Array = objective_result_payload.get("results", []) as Array
	var scorecard := build_month_scorecard(objective_results)
	emit_signal("scorecard_ready", scorecard)
	emit_signal("state_updated")

func _get_last_month_report() -> Dictionary:
	if _resolver and _resolver.has_method("get_last_month_report"):
		return _resolver.call("get_last_month_report") as Dictionary
	return {}

func _get_objective_metric(
	metric: String,
	loop_state: LoopState,
	financial_snapshot: Dictionary,
	last_month_report: Dictionary,
	context: Dictionary
) -> float:
	if context.has(metric):
		return float(context.get(metric, 0.0))
	match metric:
		"cash":
			var balance_sheet: Dictionary = financial_snapshot.get("balance_sheet", {}) as Dictionary
			return float(balance_sheet.get("cash", financial_snapshot.get("cash", 0.0)))
		"audit_score":
			return float(loop_state.audit_score)
		"points":
			return float(loop_state.points)
		"operating_margin":
			var report_kpis: Dictionary = last_month_report.get("kpis", {}) as Dictionary
			var financial_kpis: Dictionary = financial_snapshot.get("kpis", {}) as Dictionary
			return float(report_kpis.get("operating_margin", financial_kpis.get("operating_margin", 0.0)))
		"dscr":
			var report_kpis_dscr: Dictionary = last_month_report.get("kpis", {}) as Dictionary
			var financial_kpis_dscr: Dictionary = financial_snapshot.get("kpis", {}) as Dictionary
			return float(report_kpis_dscr.get("dscr", financial_kpis_dscr.get("dscr", 0.0)))
		_:
			return 0.0

func _compare_metric(actual: float, operator: String, target: float) -> bool:
	match operator:
		">=":
			return actual >= target
		">":
			return actual > target
		"<=":
			return actual <= target
		"<":
			return actual < target
		"==":
			return absf(actual - target) < 0.0001
		_:
			return false

func _objective_success_message(objective_id: String, unlocks: Array[String]) -> String:
	if objective_id == "obj_cash" and unlocks.has("DEBT_DESK"):
		return "Cash objective met. Debt Desk unlocked."
	if objective_id == "obj_route_incentive":
		return "Route incentive economics held above the operating margin threshold. Contract Review unlocked."
	if objective_id == "obj_cash_month2":
		return "Month 2 cash floor held. Liquidity survived the growth experiment."
	if unlocks.is_empty():
		return "Objective met."
	return "Objective met. Unlocked: %s." % ", ".join(PackedStringArray(unlocks))

func _objective_failure_message(objective_id: String) -> String:
	if objective_id == "obj_cash":
		return "Cash objective missed. Debt Desk remains locked."
	if objective_id == "obj_route_incentive":
		return "Route incentive economics missed the margin target. The board sees growth, but the ledger sees indigestion."
	if objective_id == "obj_cash_month2":
		return "Month 2 cash floor missed. Growth ate the runway."
	return "Objective missed."

func _read_json(p: String) -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(p)
	var parsed: Variant = JSON.parse_string(txt)   # parse returns Variant in 4.x
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Invalid JSON at " + p)
	return {}
