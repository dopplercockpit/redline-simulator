# res://engine/engine.gd
extends Node

signal state_updated()
signal month_closed(report: Dictionary)

var time
var state
var rng
var finance

func _ready():
	# instantiate modules
	time = load("res://engine/Time.gd").new()
	state = load("res://engine/State.gd").new()
	rng = load("res://engine/RNG.gd").new()
	finance = load("res://engine/Finance.gd").new()

	# load scenario & seed RNG
	_load_scenario("res://data/scenarios/flightpath/scenario_001.json")
	emit_signal("state_updated")

func _load_scenario(path: String):
	var cfg := _read_json(path)
	rng.set_seed(int(cfg.get("meta", {}).get("seed", 123456)))
	time.init(cfg.get("time", {}))
	state.reset()
	state.load_config(cfg.get("initial_state", {}))
	# Keep module inits here if/when added later (market, ops, events...)
	Telemetry.init_run(cfg.get("meta", {}))

func tick(days: int = 1):
	# Advance day-by-day for deterministic accounting
	for i in days:
		finance.apply_day(state, time.today())
		time.advance_day()
	if time.is_month_end():
		var report: Dictionary = finance.close_month(state, time.current_month())
		Telemetry.log_month(report)
		emit_signal("month_closed", report)
	emit_signal("state_updated")

func _read_json(p: String) -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(p)
	var parsed: Variant = JSON.parse_string(txt)   # parse returns Variant in 4.x
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("Invalid JSON at " + p)
	return {}
