extends CanvasLayer

@onready var body_label: RichTextLabel = $PanelContainer/ScrollContainer/VBox/Body
@onready var refresh_button: Button = $PanelContainer/ScrollContainer/VBox/RefreshReview
@onready var preview_button: Button = $PanelContainer/ScrollContainer/VBox/PreviewExportMarkdown
@onready var export_button: Button = $PanelContainer/ScrollContainer/VBox/ExportSummary
@onready var close_button: Button = $PanelContainer/ScrollContainer/VBox/Close

func _ready() -> void:
	visible = false
	if refresh_button and not refresh_button.pressed.is_connected(_render_review):
		refresh_button.pressed.connect(_render_review)
	if preview_button and not preview_button.pressed.is_connected(_render_markdown_preview):
		preview_button.pressed.connect(_render_markdown_preview)
	if export_button and not export_button.pressed.is_connected(_on_export_pressed):
		export_button.pressed.connect(_on_export_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func open_review() -> void:
	visible = true
	_render_review()

func _render_review() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("get_review_payload"):
		_set_body("GameManager review payload unavailable.")
		return
	var payload: Dictionary = manager.call("get_review_payload") as Dictionary
	var snapshot: Dictionary = payload.get("snapshot", {}) as Dictionary
	var timeline: Array = payload.get("timeline", []) as Array
	_set_body(_build_review_text(snapshot, timeline))

func _render_markdown_preview() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("preview_export_markdown"):
		_set_body("Markdown preview unavailable.")
		return
	_set_body(manager.call("preview_export_markdown") as String)

func _on_export_pressed() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("export_run_summary"):
		_set_body("Export unavailable.")
		return
	var result: Dictionary = manager.call("export_run_summary") as Dictionary
	if bool(result.get("ok", false)):
		_set_body("Export complete.\nPath: %s" % str(result.get("path", "")))
	else:
		_set_body("Export failed.\n%s" % str(result.get("errors", [])))

func _build_review_text(snapshot: Dictionary, timeline: Array) -> String:
	var loop: Dictionary = snapshot.get("loop", {}) as Dictionary
	var financial: Dictionary = snapshot.get("financial", {}) as Dictionary
	var balance_sheet: Dictionary = financial.get("balance_sheet", {}) as Dictionary
	var objectives: Dictionary = snapshot.get("objectives", {}) as Dictionary
	var contract_reviews: Dictionary = snapshot.get("contract_reviews", {}) as Dictionary
	var remediation: Dictionary = snapshot.get("audit_room_remediation", {}) as Dictionary
	var kpis: Dictionary = financial.get("kpis", {}) as Dictionary
	var lines: Array[String] = []
	lines.append("Current Position")
	lines.append("- Week: %d" % int(loop.get("week_number", loop.get("week", 0))))
	lines.append("- Month: %d" % int(loop.get("month_number", loop.get("month", 1))))
	lines.append("- Cash: %s" % _format_currency(float(balance_sheet.get("cash", financial.get("cash", 0.0)))))
	lines.append("- Total Debt: %s" % _format_currency(_extract_total_debt(balance_sheet)))
	lines.append("- Points: %d" % int(loop.get("points", 0)))
	lines.append("- Audit Score: %d" % int(loop.get("audit_score", 0)))
	lines.append("- Ops Risk: %s" % _format_number(float(loop.get("ops_risk", 0.0))))
	lines.append("- Reputation: %s" % _format_number(float(loop.get("reputation", 0.0))))
	lines.append("")
	lines.append("Financial Snapshot")
	lines.append("- Operating Margin: %.1f%%" % (float(kpis.get("operating_margin", 0.0)) * 100.0))
	lines.append("- DSCR: %s" % _format_number(float(kpis.get("dscr", 0.0))))
	lines.append("")
	lines.append("Objectives")
	lines.append(_format_objectives(objectives))
	lines.append("")
	lines.append("Decision Timeline")
	lines.append(_format_timeline(timeline))
	lines.append("")
	lines.append("Contract Reviews")
	lines.append(_format_contract_reviews(contract_reviews))
	lines.append("")
	lines.append("Audit Room")
	lines.append(_format_audit_room(remediation))
	lines.append("")
	lines.append("Teaching Discussion Prompts")
	lines.append("- What changed cash without creating revenue?")
	lines.append("- When did debt improve runway, and when did it add pressure?")
	lines.append("- Which contract term created a finance outcome later?")
	lines.append("- What would you tell the board next?")
	return "\n".join(PackedStringArray(lines))

func _format_timeline(timeline: Array) -> String:
	if timeline.is_empty():
		return "- No timeline events."
	var lines: Array[String] = []
	for event_value in timeline:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value as Dictionary
		var amount_text := ""
		if event.has("amount") and absf(float(event.get("amount", 0.0))) > 0.001:
			amount_text = " | cash %s" % _format_currency(float(event.get("amount", 0.0)))
		lines.append("- Week %d | %s | %s%s\n  %s" % [
			int(event.get("week", 0)),
			str(event.get("type", "event")),
			str(event.get("title", "")),
			amount_text,
			str(event.get("detail", ""))
		])
	return "\n".join(PackedStringArray(lines))

func _format_objectives(objectives: Dictionary) -> String:
	if objectives.is_empty():
		return "- No objectives evaluated."
	var lines: Array[String] = []
	for key in objectives.keys():
		var result: Dictionary = objectives.get(key, {}) as Dictionary
		lines.append("- %s: %s | actual %s vs target %s\n  %s" % [
			str(result.get("id", key)),
			"PASSED" if bool(result.get("passed", false)) else "MISSED",
			_format_number(float(result.get("actual", 0.0))),
			_format_number(float(result.get("target", 0.0))),
			str(result.get("message", ""))
		])
	return "\n".join(PackedStringArray(lines))

func _format_contract_reviews(contract_reviews: Dictionary) -> String:
	if contract_reviews.is_empty():
		return "- None."
	var lines: Array[String] = []
	for key in contract_reviews.keys():
		var review: Dictionary = contract_reviews.get(key, {}) as Dictionary
		lines.append("- %s: %s / %s risk / clawback %s / service %s" % [
			str(key),
			str(review.get("status", "unknown")),
			str(review.get("risk_rating", "unknown")),
			str(review.get("clawback_strength", "unknown")),
			"yes" if bool(review.get("minimum_service_commitment", false)) else "no"
		])
	return "\n".join(PackedStringArray(lines))

func _format_audit_room(remediation: Dictionary) -> String:
	if remediation.is_empty():
		return "- No Audit Room remediation recorded."
	return "- %s: %s" % [
		str(remediation.get("remediation_id", "remediation")),
		str(remediation.get("feedback", ""))
	]

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

func _format_number(value: float) -> String:
	if absf(value - round(value)) < 0.001:
		return str(int(round(value)))
	return "%.2f" % value

func _extract_total_debt(balance_sheet: Dictionary) -> float:
	if balance_sheet.has("total_debt"):
		return float(balance_sheet.get("total_debt", 0.0))
	return float(balance_sheet.get("short_term_debt", 0.0)) + float(balance_sheet.get("debt_term_loan", 0.0))

func _manager() -> Node:
	return get_node_or_null("/root/GameManager")

func _set_body(text: String) -> void:
	if body_label:
		body_label.text = text

func _on_close_pressed() -> void:
	visible = false
