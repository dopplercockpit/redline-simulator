# res://engine/GameManager.gd
extends Node

signal turn_advanced(new_week: int, new_month: int)
signal month_end_ready(month_number: int, report: Dictionary)
signal mission_triggered(mission_id: String)
signal state_updated()

const DEFAULT_SCENARIO_PATH := "res://data/scenarios/flightpath/scenario_001.json"

var _resolver: Node = null

func _ready() -> void:
	_resolver = get_node_or_null("/root/DecisionResolver")
	if _resolver == null:
		push_warning("DecisionResolver autoload missing; GameManager is inactive.")

func load_scenario(path: String = DEFAULT_SCENARIO_PATH) -> void:
	var cfg := _read_json(path)
	if cfg.is_empty():
		return
	load_scenario_config(cfg)

func load_scenario_config(cfg: Dictionary) -> void:
	if _resolver:
		_resolver.call("load_scenario", cfg)
	emit_signal("state_updated")

func advance_week(use_legacy_burn: bool = true) -> Dictionary:
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

func submit_intent(intent: Dictionary) -> Dictionary:
	if _resolver == null:
		return {}
	var impacts: Dictionary = _resolver.call("resolve_intent", intent) as Dictionary
	emit_signal("state_updated")
	return impacts

func get_financial_state_ref() -> GameStateData:
	if _resolver:
		return _resolver.call("get_financial_state_ref") as GameStateData
	return null

func get_financial_snapshot() -> Dictionary:
	if _resolver:
		return _resolver.call("get_financial_snapshot") as Dictionary
	return {}

func get_loop_snapshot() -> Dictionary:
	if _resolver:
		return _resolver.call("get_loop_snapshot") as Dictionary
	return {}

func _read_json(p: String) -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(p)
	var parsed: Variant = JSON.parse_string(txt)   # parse returns Variant in 4.x
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Invalid JSON at " + p)
	return {}
