extends CanvasLayer
@onready var body: RichTextLabel = $PanelContainer/ScrollContainer/VBoxContainer/Body

var _backend_client: BackendClient
var _local_compendium_text: String = "[b]Missing compendium[/b]"
var _nudge_request_in_flight: bool = false

func load_compendium(path: String) -> void:
	_local_compendium_text = _load_static_compendium(path)
	body.text = _local_compendium_text
	_request_dynamic_nudge()


func _load_static_compendium(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "[b]Missing compendium[/b]"
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return "[b]Malformed compendium[/b]"

	var sections: Array = ["pricing","cogs","working_capital","risk","cash_flow","margin","inventory"]
	var t: String = ""
	for s in sections:
		if data.has(s):
			t += "[b]%s[/b]\n%s\n\n" % [s.capitalize(), str(data[s])]
	if t == "":
		t = "Compendium is empty. (Add FP&A bullets.)"
	return t

func _ready() -> void:
	_backend_client = BackendClient.new()
	add_child(_backend_client)
	if not _backend_client.nudge_request_finished.is_connected(_on_nudge_finished):
		_backend_client.nudge_request_finished.connect(_on_nudge_finished)

	var btn: Button = $PanelContainer/ScrollContainer/VBoxContainer/Close
	btn.pressed.connect(func():
		visible = false
	)


func _request_dynamic_nudge() -> void:
	if _backend_client == null:
		body.text = _prepend_fallback_nudge(_local_compendium_text)
		return
	if _nudge_request_in_flight:
		return

	var context := _build_request_context()
	var payload := _build_nudge_payload(context)
	_nudge_request_in_flight = true
	_backend_client.fetch_nudge(context, payload)


func _build_request_context() -> Dictionary:
	var loop_snapshot: Dictionary = {}
	var loop_system: Node = get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_snapshot"):
		loop_snapshot = loop_system.call("get_snapshot") as Dictionary

	var month := int(loop_snapshot.get("month_number", 1))
	var week := int(loop_snapshot.get("week_number", 1))
	var audit_score := float(loop_snapshot.get("audit_score", 0.0))

	var scenario_id := "unknown_scenario"
	var scenario_version := "1.0.0"
	var domain_module := "redline"
	var parent_node := get_parent()
	if parent_node != null:
		var scenario_variant: Variant = parent_node.get("current_scenario")
		if typeof(scenario_variant) == TYPE_DICTIONARY:
			var scenario := scenario_variant as Dictionary
			scenario_id = str(scenario.get("id", scenario_id))
			scenario_version = str(scenario.get("version", scenario_version))
			domain_module = str(scenario.get("domain_module", domain_module))

	return {
		"audit_score": audit_score,
		"month": month,
		"week": week,
		"client": {
			"platform": OS.get_name().to_lower(),
			"build_version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
			"environment": "local"
		},
		"scenario": {
			"scenario_id": scenario_id,
			"scenario_version": scenario_version,
			"domain_module": domain_module
		},
		"run_context": {
			# TODO: replace placeholders with canonical run/session ids when runtime services expose them.
			"run_id": "local_run",
			"turn_index": max(week, 0),
			"week": max(week, 1),
			"month": max(month, 1),
			"quarter": int(((max(month, 1) - 1) / 3) + 1),
			"year": 1,
			"seed": 0
		}
	}


func _build_nudge_payload(context: Dictionary) -> Dictionary:
	var metrics := _extract_nudge_metrics(context)
	var problem_hint := "audit readiness"
	if metrics.has("margin_pct") and float(metrics.get("margin_pct", 0.0)) < 10.0:
		problem_hint = "margin deterioration"
	elif metrics.has("audit_score") and float(metrics.get("audit_score", 0.0)) < 60.0:
		problem_hint = "audit readiness"

	return {
		"player_context": {
			"experience_level": "student",
			"hint_level": "moderate"
		},
		"situation": {
			"screen": "compendium_panel",
			"problem_hint": problem_hint,
			"recent_actions": ["open_compendium"]
		},
		"metrics": metrics,
		"constraints": {
			"max_words": 80,
			"tone": "supportive"
		}
	}


func _extract_nudge_metrics(context: Dictionary) -> Dictionary:
	var metrics := {"audit_score": float(context.get("audit_score", 0.0))}

	var resolver: Node = get_node_or_null("/root/DecisionResolver")
	if resolver and resolver.has_method("get_financial_state_ref"):
		var state: Object = resolver.call("get_financial_state_ref")
		if state and state.has_method("get_financial_summary"):
			var summary := state.call("get_financial_summary") as Dictionary
			var income := summary.get("income_statement", {}) as Dictionary
			var revenue := float(income.get("total_rev", income.get("net_sales", 0.0)))
			var net_income := float(income.get("net_income", 0.0))
			if revenue > 0.0:
				metrics["margin_pct"] = (net_income / revenue) * 100.0

	return metrics


func _on_nudge_finished(result: Dictionary) -> void:
	_nudge_request_in_flight = false

	if not bool(result.get("ok", false)):
		push_warning("Dynamic nudge unavailable: %s" % str(result.get("error", "unknown")))
		body.text = _prepend_fallback_nudge(_local_compendium_text)
		return

	var nudge_variant: Variant = result.get("nudge", {})
	if typeof(nudge_variant) != TYPE_DICTIONARY:
		body.text = _prepend_fallback_nudge(_local_compendium_text)
		return

	var nudge := nudge_variant as Dictionary
	var title := str(nudge.get("title", "Coach Note"))
	var text := str(nudge.get("body", ""))
	var tags_variant: Variant = nudge.get("concept_tags", [])
	var tags_text := ""
	if typeof(tags_variant) == TYPE_ARRAY:
		var tags := tags_variant as Array
		if not tags.is_empty():
			var tag_strings: Array[String] = []
			for tag in tags:
				tag_strings.append(str(tag))
			tags_text = "\n[i]Concepts: %s[/i]" % ", ".join(tag_strings)

	body.text = "[b]Coach Nudge: %s[/b]\n%s%s\n\n%s" % [title, text, tags_text, _local_compendium_text]


func _prepend_fallback_nudge(base_text: String) -> String:
	return (
		"[b]Coach Nudge: Review Drivers[/b]\n"
		"Check margin, cash discipline, and audit posture before finalizing your next move.\n\n"
		+ base_text
	)
