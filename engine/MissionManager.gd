# res://engine/MissionManager.gd
extends Node

signal mission_added(mission: Dictionary)
signal mission_completed(result: Dictionary)
signal inbox_updated(inbox: Array)

const SAVE_PATH := "user://save.cfg"
const SAVE_SECTION := "progress"
const MONTH_CLOSE_DEF_ID := "MISSION_MONTH_CLOSE_V1"
const ROUTE_INCENTIVE_CLOSE_DEF_ID := "MISSION_MONTH_CLOSE_ROUTE_INCENTIVE_V1"
const AUDIT_STUB_ID := "MISSION_AUDIT_STUB_V1"
const AUDIT_THRESHOLD := 100

var _state_ref: LoopState = null
var _missions: Dictionary = {}
var _inbox: Array = []
var _mission_context: Dictionary = {}

func _ready() -> void:
	_load_mission_defs()

func init_from_state(state_ref) -> void:
	_state_ref = state_ref as LoopState
	_ensure_state_defaults()
	_load_progress()
	_inbox = _state_ref.inbox
	emit_signal("inbox_updated", get_inbox())

func enqueue_month_close(report: Dictionary, loop_snapshot: Dictionary) -> void:
	if _state_ref == null:
		return
	var created_month: int = int(report.get("month", loop_snapshot.get("month_number", 0) - 1))
	if created_month <= 0:
		created_month = int(loop_snapshot.get("month_number", 0))

	# Patch 5: Month 2 uses the route incentive close mission; later months fall back to the generic close.
	var def_id := _month_close_definition_id(created_month)
	var def: Dictionary = _missions.get(def_id, {}) as Dictionary
	if def.is_empty():
		push_warning("Mission definition missing: " + def_id)
		return

	var created_week: int = int(loop_snapshot.get("week_number", 0))

	for item in _inbox:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("type", "")) == "month_close" and int(item.get("created_month", -1)) == created_month:
			var status := str(item.get("status", "queued"))
			if status == "queued" or status == "active":
				return

	var mission_id := "%s_M%d" % [def_id, created_month]
	if _state_ref.completed_missions.has(mission_id):
		return

	var inbox_item := {
		"mission_id": mission_id,
		"title": str(def.get("title", "Month-End Close")),
		"type": str(def.get("type", "month_close")),
		"status": "queued",
		"created_week": created_week,
		"created_month": created_month
	}
	_inbox.append(inbox_item)
	_state_ref.inbox = _inbox
	_mission_context[mission_id] = {
		"definition_id": def.get("id", def_id),
		"report": report,
		"loop_snapshot": loop_snapshot
	}
	_save_progress()
	_telemetry_log("mission_enqueued", {
		"mission_id": mission_id,
		"week": created_week,
		"month": created_month
	})
	emit_signal("mission_added", inbox_item)
	emit_signal("inbox_updated", get_inbox())

func get_inbox() -> Array:
	return _inbox.duplicate(true)

func start_mission(mission_id: String) -> void:
	if _state_ref == null:
		return

	var idx := _find_inbox_index(mission_id)
	if idx != -1:
		var item: Dictionary = _inbox[idx] as Dictionary
		if str(item.get("status", "")) == "completed":
			return
		item["status"] = "active"
		_inbox[idx] = item
		_state_ref.inbox = _inbox
		_save_progress()
		emit_signal("inbox_updated", get_inbox())

	var def_id := _resolve_definition_id(mission_id)
	var def: Dictionary = _missions.get(def_id, {}) as Dictionary
	if def.is_empty():
		push_warning("Mission definition missing: " + def_id)
		return

	var quiz_scene := load("res://ui/BoardroomQuiz.tscn") as PackedScene
	if quiz_scene == null:
		push_error("MissionManager: Failed to load BoardroomQuiz.tscn")
		return
	var quiz := quiz_scene.instantiate()
	var loop_snapshot: Dictionary = {}
	var context: Variant = _mission_context.get(mission_id, {})
	if typeof(context) == TYPE_DICTIONARY:
		loop_snapshot = (context as Dictionary).get("loop_snapshot", {}) as Dictionary

	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(quiz)
		if quiz.has_method("setup"):
			quiz.call_deferred("setup", mission_id, def, loop_snapshot)

func complete_mission(mission_id: String, result: Dictionary) -> void:
	if _state_ref == null:
		return

	var def_id := _resolve_definition_id(mission_id)
	var def: Dictionary = _missions.get(def_id, {}) as Dictionary
	var scoring: Dictionary = def.get("scoring", {}) as Dictionary
	var points_per_correct: int = int(scoring.get("points_per_correct", 0))
	var audit_per_wrong: int = int(scoring.get("audit_per_wrong", 0))
	var correct: int = int(result.get("correct", 0))
	var wrong: int = int(result.get("wrong", 0))
	var score: int = int(result.get("score", correct * points_per_correct))

	_state_ref.points += correct * points_per_correct
	_state_ref.audit_score += wrong * audit_per_wrong
	_state_ref.completed_missions[mission_id] = true

	var snap := _get_loop_snapshot()
	var week_num: int = int(snap.get("week_number", snap.get("week", 0)))
	var month_num: int = int(snap.get("month_number", snap.get("month", 0)))
	_state_ref.mission_log.append({
		"mission_id": mission_id,
		"completed_at_week": week_num,
		"completed_at_month": month_num,
		"score": score,
		"correct": correct,
		"wrong": wrong
	})

	_set_inbox_status(mission_id, "completed")
	_save_progress()

	_telemetry_log("mission_completed", {
		"mission_id": mission_id,
		"score": score,
		"correct": correct,
		"wrong": wrong,
		"points_total": _state_ref.points,
		"audit_score": _state_ref.audit_score
	})

	var completed_payload := {
		"mission_id": mission_id,
		"score": score,
		"correct": correct,
		"wrong": wrong
	}
	emit_signal("mission_completed", completed_payload)

	if _maybe_enqueue_audit_stub():
		_save_progress()

	emit_signal("inbox_updated", get_inbox())

func _ensure_state_defaults() -> void:
	if _state_ref == null:
		return
	if typeof(_state_ref.points) != TYPE_INT:
		_state_ref.points = 0
	if typeof(_state_ref.audit_score) != TYPE_INT:
		_state_ref.audit_score = 0
	if typeof(_state_ref.completed_missions) != TYPE_DICTIONARY:
		_state_ref.completed_missions = {}
	if typeof(_state_ref.mission_log) != TYPE_ARRAY:
		_state_ref.mission_log = []
	if typeof(_state_ref.inbox) != TYPE_ARRAY:
		_state_ref.inbox = []

func _load_mission_defs() -> void:
	_load_mission_file("res://data/missions/month_close_v1.json")
	_load_mission_file("res://data/missions/month_close_route_incentive_v1.json")

func _load_mission_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Mission file missing: " + path)
		return
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Mission file invalid: " + path)
		return
	var def: Dictionary = parsed as Dictionary
	var def_id := str(def.get("id", ""))
	if def_id == "":
		push_warning("Mission missing id: " + path)
		return
	_missions[def_id] = def

func _load_progress() -> void:
	if _state_ref == null:
		return
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		push_warning("Failed to load save: " + str(err))
		return

	_state_ref.points = int(cfg.get_value(SAVE_SECTION, "points", _state_ref.points))
	_state_ref.audit_score = int(cfg.get_value(SAVE_SECTION, "audit_score", _state_ref.audit_score))

	var completed: Variant = cfg.get_value(SAVE_SECTION, "completed_missions", _state_ref.completed_missions)
	_state_ref.completed_missions = completed if typeof(completed) == TYPE_DICTIONARY else {}

	var log_entries: Variant = cfg.get_value(SAVE_SECTION, "mission_log", _state_ref.mission_log)
	_state_ref.mission_log = log_entries if typeof(log_entries) == TYPE_ARRAY else []

	var inbox_entries: Variant = cfg.get_value(SAVE_SECTION, "inbox", _state_ref.inbox)
	_state_ref.inbox = inbox_entries if typeof(inbox_entries) == TYPE_ARRAY else []

func _save_progress() -> void:
	if _state_ref == null:
		return
	var cfg := ConfigFile.new()
	cfg.set_value(SAVE_SECTION, "points", _state_ref.points)
	cfg.set_value(SAVE_SECTION, "audit_score", _state_ref.audit_score)
	cfg.set_value(SAVE_SECTION, "completed_missions", _state_ref.completed_missions)
	cfg.set_value(SAVE_SECTION, "mission_log", _state_ref.mission_log)
	cfg.set_value(SAVE_SECTION, "inbox", _inbox)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Failed to save progress: " + str(err))

func _find_inbox_index(mission_id: String) -> int:
	for i in range(_inbox.size()):
		var item: Variant = _inbox[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("mission_id", "")) == mission_id:
			return i
	return -1

func _set_inbox_status(mission_id: String, status: String) -> void:
	var idx := _find_inbox_index(mission_id)
	if idx == -1:
		return
	var item: Dictionary = _inbox[idx] as Dictionary
	item["status"] = status
	_inbox[idx] = item
	_state_ref.inbox = _inbox

func _resolve_definition_id(mission_id: String) -> String:
	var context: Variant = _mission_context.get(mission_id, {})
	if typeof(context) == TYPE_DICTIONARY:
		var def_id := str((context as Dictionary).get("definition_id", ""))
		if def_id != "":
			return def_id
	if mission_id.begins_with(MONTH_CLOSE_DEF_ID):
		return MONTH_CLOSE_DEF_ID
	if mission_id.begins_with(ROUTE_INCENTIVE_CLOSE_DEF_ID):
		return ROUTE_INCENTIVE_CLOSE_DEF_ID
	return mission_id

func _month_close_definition_id(month_number: int) -> String:
	if month_number == 2:
		return ROUTE_INCENTIVE_CLOSE_DEF_ID
	return MONTH_CLOSE_DEF_ID

func _get_loop_snapshot() -> Dictionary:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_loop_snapshot"):
		var snap: Variant = gm.call("get_loop_snapshot")
		if typeof(snap) == TYPE_DICTIONARY:
			return snap as Dictionary
	var loop_system := get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_snapshot"):
		var snap: Variant = loop_system.call("get_snapshot")
		if typeof(snap) == TYPE_DICTIONARY:
			return snap as Dictionary
	return {}

func _maybe_enqueue_audit_stub() -> bool:
	if _state_ref.audit_score < AUDIT_THRESHOLD:
		return false
	if _state_ref.completed_missions.has(AUDIT_STUB_ID):
		return false
	if _find_inbox_index(AUDIT_STUB_ID) != -1:
		return false

	var snap := _get_loop_snapshot()
	var week_num: int = int(snap.get("week_number", snap.get("week", 0)))
	var month_num: int = int(snap.get("month_number", snap.get("month", 0)))

	var inbox_item := {
		"mission_id": AUDIT_STUB_ID,
		"title": "Audit Triggered (Stub)",
		"type": "audit",
		"status": "queued",
		"created_week": week_num,
		"created_month": month_num
	}
	_inbox.append(inbox_item)
	_state_ref.inbox = _inbox
	emit_signal("mission_added", inbox_item)
	return true

func _telemetry_log(event_name: String, payload: Dictionary) -> void:
	var telemetry := get_node_or_null("/root/Telemetry")
	if telemetry and telemetry.has_method("log_event"):
		telemetry.call("log_event", event_name, payload)
	elif telemetry:
		# TODO: add log_event support to Telemetry autoload.
		pass
