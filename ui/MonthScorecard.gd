extends CanvasLayer

@onready var title_label: Label = $Dimmer/PanelContainer/VBox/Title
@onready var body_label: RichTextLabel = $Dimmer/PanelContainer/VBox/Body
@onready var close_button: Button = $Dimmer/PanelContainer/VBox/Close

func _ready() -> void:
	visible = false
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_scorecard(scorecard: Dictionary) -> void:
	visible = true
	if title_label:
		title_label.text = str(scorecard.get("title", "Month Scorecard"))
	if body_label:
		body_label.text = _build_body(scorecard)

func _build_body(scorecard: Dictionary) -> String:
	var objective_results: Array = scorecard.get("objective_results", []) as Array
	var completed_missions: Array = scorecard.get("completed_missions", []) as Array
	var unlocks: Dictionary = scorecard.get("unlocks", {}) as Dictionary
	var contract_reviews: Dictionary = scorecard.get("contract_reviews", {}) as Dictionary
	var audit_room_remediation: Dictionary = scorecard.get("audit_room_remediation", {}) as Dictionary

	var lines: Array[String] = []
	lines.append("Cash: %s" % _format_currency(float(scorecard.get("cash", 0.0))))
	lines.append("Total Debt: %s" % _format_currency(float(scorecard.get("total_debt", 0.0))))
	lines.append("Operating Margin: %s" % _format_percent(float(scorecard.get("operating_margin", 0.0))))
	lines.append("DSCR: %.1fx" % float(scorecard.get("dscr", 0.0)))
	lines.append("Points: %d" % int(scorecard.get("points", 0)))
	lines.append("Audit Score: %d" % int(scorecard.get("audit_score", 0)))
	lines.append("Reputation: %s" % _format_number(float(scorecard.get("reputation", 0.0))))
	lines.append("Ops Risk: %s" % _format_number(float(scorecard.get("ops_risk", 0.0))))
	lines.append("")
	lines.append("Completed Missions: %s" % _format_array(completed_missions))
	lines.append("Unlocked Tools: %s" % _format_unlocks(unlocks))
	lines.append("Contract Reviews: %s" % _format_contract_reviews(contract_reviews))
	lines.append("Audit Room Remediation: %s" % _format_audit_room_remediation(audit_room_remediation))
	lines.append("")

	if objective_results.is_empty():
		lines.append("Objective: No objective evaluated.")
	else:
		for result_value in objective_results:
			if typeof(result_value) != TYPE_DICTIONARY:
				continue
			var result: Dictionary = result_value as Dictionary
			lines.append("Objective: %s" % str(result.get("id", "objective")))
			lines.append(
				"Metric: %s %s %s" % [
					str(result.get("metric", "metric")),
					str(result.get("operator", ">=")),
					_format_target(result)
				]
			)
			lines.append("Result: %s" % ("PASSED" if bool(result.get("passed", false)) else "MISSED"))
			lines.append("Reward: +%d points" % int(result.get("points_awarded", 0)))
			var result_unlocks: Array = result.get("unlocks", []) as Array
			lines.append("Unlocked: %s" % _format_array(result_unlocks))
			lines.append("Note: %s" % str(result.get("message", "")))
			lines.append("")

	var any_passed := false
	for result_value in objective_results:
		if typeof(result_value) == TYPE_DICTIONARY and bool((result_value as Dictionary).get("passed", false)):
			any_passed = true
			break
	if any_passed:
		lines.append("Comment: The board has a clearer story. Now the numbers need to keep earning it.")
	else:
		lines.append("Comment: The board saw the gap. Fix the economics before calling it strategy.")

	return "\n".join(PackedStringArray(lines))

func _on_close_pressed() -> void:
	visible = false

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

func _format_percent(value: float) -> String:
	return "%.1f%%" % (value * 100.0)

func _format_target(result: Dictionary) -> String:
	var metric := str(result.get("metric", ""))
	var target := float(result.get("target", 0.0))
	if metric == "operating_margin":
		return _format_percent(target)
	if metric == "cash":
		return _format_currency(target)
	return _format_number(target)

func _format_number(value: float) -> String:
	if absf(value - round(value)) < 0.001:
		return str(int(round(value)))
	return "%.1f" % value

func _format_array(values: Array) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	if parts.is_empty():
		return "None"
	return ", ".join(PackedStringArray(parts))

func _format_contract_reviews(contract_reviews: Dictionary) -> String:
	var parts: Array[String] = []
	for key in contract_reviews.keys():
		var value: Variant = contract_reviews.get(key)
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var review: Dictionary = value as Dictionary
		parts.append("%s: %s / %s risk" % [
			str(key),
			str(review.get("status", "unknown")),
			str(review.get("risk_rating", "unknown"))
		])
	if parts.is_empty():
		return "None"
	return ", ".join(PackedStringArray(parts))

func _format_audit_room_remediation(remediation: Dictionary) -> String:
	if remediation.is_empty():
		return "None"
	return "%s: %s" % [
		str(remediation.get("remediation_id", "remediation")),
		str(remediation.get("feedback", ""))
	]

func _format_unlocks(unlocks: Dictionary) -> String:
	var parts: Array[String] = []
	for key in unlocks.keys():
		if bool(unlocks.get(key, false)):
			parts.append(str(key))
	if parts.is_empty():
		return "None"
	return ", ".join(PackedStringArray(parts))
