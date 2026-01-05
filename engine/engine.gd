# res://engine/engine.gd
extends Node

signal state_updated()
signal month_closed(report: Dictionary)

var rng
var telemetry
var _manager: Node = null
const DEFAULT_SCENARIO_PATH := "res://data/scenarios/flightpath/scenario_001.json"

func _ready() -> void:
	rng = load("res://engine/rng.gd").new()
	telemetry = load("res://engine/telemetry.gd").new()
	add_child(telemetry)

	_manager = get_node_or_null("/root/GameManager")
	if _manager == null:
		push_warning("GameManager autoload missing; RSE is idle.")
		return

	# Back-compat: load default scenario on boot and seed RNG.
	var cfg := _read_json(DEFAULT_SCENARIO_PATH)
	if not cfg.is_empty():
		rng.set_seed(int(cfg.get("meta", {}).get("seed", 123456)))
		telemetry.init_run(cfg.get("meta", {}))
		_manager.call("load_scenario_config", cfg)
	emit_signal("state_updated")

func tick(weeks: int = 1) -> void:
	# Weekly-only progression (no daily simulation).
	if _manager == null:
		return

	for _i in range(weeks):
		var result: Dictionary = _manager.call("advance_week") as Dictionary
		var report: Dictionary = result.get("month_report", {}) as Dictionary
		if not report.is_empty():
			telemetry.log_month(report)
			emit_signal("month_closed", report)

	emit_signal("state_updated")

func _read_json(p: String) -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(p)
	var parsed: Variant = JSON.parse_string(txt)   # parse returns Variant in 4.x
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Invalid JSON at " + p)
	return {}
