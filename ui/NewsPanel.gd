extends CanvasLayer

const BackendClientScript = preload("res://engine/BackendClient.gd")

@onready var body: RichTextLabel = $PanelContainer/ScrollContainer/VBoxContainer/Body

var _backend_client: Node
var _local_fallback_text: String = "[b]No news found[/b]"
var _news_request_in_flight: bool = false


func load_news(path: String) -> void:
	_local_fallback_text = _load_static_news(path)
	body.text = _local_fallback_text
	_request_dynamic_news()


func _ready() -> void:
	_backend_client = BackendClientScript.new()
	add_child(_backend_client)
	if not _backend_client.news_request_finished.is_connected(_on_backend_news_finished):
		_backend_client.news_request_finished.connect(_on_backend_news_finished)

	var btn: Button = $PanelContainer/ScrollContainer/VBoxContainer/Close
	btn.pressed.connect(func():
		visible = false
	)


func _load_static_news(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "[b]No news found[/b]"

	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		return "[b]Malformed news[/b]"

	var t: String = ""
	for item_variant in data:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item := item_variant as Dictionary
		var title := str(item.get("title", "Untitled"))
		var source := str(item.get("source", "Local Bulletin"))
		var blurb := str(item.get("blurb", ""))
		t += "[b]%s[/b]  [i](%s)[/i]\n%s\n\n" % [title, source, blurb]

	return t if t.strip_edges() != "" else "[b]No news found[/b]"


func _request_dynamic_news() -> void:
	if _backend_client == null:
		return
	if _news_request_in_flight:
		return

	var context := _build_request_context()
	var payload := _build_news_payload(context)
	_news_request_in_flight = true
	_backend_client.fetch_news(context, payload)


func _build_request_context() -> Dictionary:
	var loop_snapshot: Dictionary = {}
	var loop_system: Node = get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_snapshot"):
		loop_snapshot = loop_system.call("get_snapshot") as Dictionary

	var week := int(loop_snapshot.get("week_number", 1))
	var month := int(loop_snapshot.get("month_number", 1))
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
		"loop_snapshot": loop_snapshot,
		"audit_score": audit_score,
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
			# TODO: replace placeholders with canonical run/session ids once runtime exposes them.
			"run_id": "local_run",
			"turn_index": max(week, 0),
			"week": max(week, 1),
			"month": max(month, 1),
			"quarter": int(((max(month, 1) - 1) / 3) + 1),
			"year": 1,
			"seed": 0
		}
	}


func _build_news_payload(context: Dictionary) -> Dictionary:
	var kpis := _extract_kpis(context)
	var loop_snapshot: Dictionary = context.get("loop_snapshot", {}) as Dictionary
	var week := int(loop_snapshot.get("week_number", 1))
	var recent_events := [
		{
			"event_id": "weekly_snapshot_%d" % max(week, 1),
			"event_type": "weekly_update",
			"headline_hint": "Week %d operating snapshot" % max(week, 1),
			"severity": "medium"
		}
	]

	return {
		"news_type": "weekly_wrap",
		"tone": "professional",
		"audience": "internal_exec",
		"recent_events": recent_events,
		"kpis": kpis,
		"constraints": {"max_items": 2, "max_words_per_item": 90}
	}


func _extract_kpis(context: Dictionary) -> Dictionary:
	var revenue := 0.0
	var expense := 0.0
	var cash := 0.0
	var margin_pct := 0.0
	var audit_score := float(context.get("audit_score", 0.0))

	var resolver: Node = get_node_or_null("/root/DecisionResolver")
	if resolver and resolver.has_method("get_financial_state_ref"):
		var state: Object = resolver.call("get_financial_state_ref")
		if state and state.has_method("get_financial_summary"):
			var summary := state.call("get_financial_summary") as Dictionary
			var income := summary.get("income_statement", {}) as Dictionary
			var balance := summary.get("balance_sheet", {}) as Dictionary
			revenue = float(income.get("total_rev", income.get("net_sales", 0.0)))
			var net_income := float(income.get("net_income", 0.0))
			expense = max(revenue - net_income, 0.0)
			cash = float(balance.get("cash", 0.0))
			if revenue > 0.0:
				margin_pct = (net_income / revenue) * 100.0

	return {
		"revenue": revenue,
		"expense": expense,
		"cash": cash,
		"margin_pct": margin_pct,
		"audit_score": audit_score
	}


func _on_backend_news_finished(result: Dictionary) -> void:
	_news_request_in_flight = false

	if not bool(result.get("ok", false)):
		push_warning("Dynamic news unavailable: %s" % str(result.get("error", "unknown")))
		body.text = _local_fallback_text
		return

	var items_variant: Variant = result.get("items", [])
	if typeof(items_variant) != TYPE_ARRAY:
		return

	var items := items_variant as Array
	body.text = _format_dynamic_items(items)


func _format_dynamic_items(items: Array) -> String:
	var t := ""
	for item_variant in items:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item := item_variant as Dictionary
		var headline := str(item.get("headline", "Update"))
		var body_text := str(item.get("body", ""))
		t += "[b]%s[/b]\n%s\n\n" % [headline, body_text]

	return t if t.strip_edges() != "" else _local_fallback_text
