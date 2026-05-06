extends CanvasLayer

const AUDIT_REMEDIATIONS_PATH := "res://data/tools/audit_room/audit_remediations_v1.json"

@onready var title_label: Label = $PanelContainer/ScrollContainer/VBox/Title
@onready var body_label: RichTextLabel = $PanelContainer/ScrollContainer/VBox/Body
@onready var actions_box: VBoxContainer = $PanelContainer/ScrollContainer/VBox/Actions
@onready var close_button: Button = $PanelContainer/ScrollContainer/VBox/Close

var _dynamic_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func open_audit_room() -> void:
	visible = true
	if not _is_unlocked():
		_render_locked()
		return
	_render_review()

func _is_unlocked() -> bool:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("is_audit_room_unlocked"):
		return bool(manager.call("is_audit_room_unlocked"))
	return false

func _is_used() -> bool:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("is_audit_room_used"):
		return bool(manager.call("is_audit_room_used"))
	return false

func _load_remediations() -> Dictionary:
	if not FileAccess.file_exists(AUDIT_REMEDIATIONS_PATH):
		push_warning("Audit Room remediation file missing: " + AUDIT_REMEDIATIONS_PATH)
		return {}
	var raw := FileAccess.get_file_as_string(AUDIT_REMEDIATIONS_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	push_warning("Invalid Audit Room remediation JSON: " + AUDIT_REMEDIATIONS_PATH)
	return {}

func _render_locked() -> void:
	_clear_dynamic_buttons()
	if title_label:
		title_label.text = "Audit Room"
	if body_label:
		body_label.text = "Audit Room locked. Keep audit posture under control through Month 3 to unlock it."

func _render_review(extra_feedback: String = "") -> void:
	_clear_dynamic_buttons()
	if title_label:
		title_label.text = "Audit Room: Control Review"
	var manager := get_node_or_null("/root/GameManager")
	var snapshot: Dictionary = {}
	if manager and manager.has_method("get_run_review_snapshot"):
		snapshot = manager.call("get_run_review_snapshot") as Dictionary
	if body_label:
		var review_text := _build_review_text(snapshot)
		if extra_feedback.strip_edges() != "":
			review_text += "\n\nLatest Action:\n- " + extra_feedback
		body_label.text = review_text
	if not _is_used():
		_render_remediation_buttons()

func _render_remediation_buttons() -> void:
	var data := _load_remediations()
	var remediations_value: Variant = data.get("remediations", [])
	if typeof(remediations_value) != TYPE_ARRAY:
		return
	var remediations: Array = remediations_value as Array
	for choice_value in remediations:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		var button := Button.new()
		button.text = "%s - %s" % [
			str(choice.get("label", choice.get("id", "Remediation"))),
			str(choice.get("description", ""))
		]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_remediation_pressed.bind(choice))
		actions_box.add_child(button)
		_dynamic_buttons.append(button)

func _on_remediation_pressed(choice: Dictionary) -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.has_method("submit_audit_room_choice"):
		if body_label:
			body_label.text = "Audit Room unavailable. GameManager is missing."
		return
	var remediation_id := str(choice.get("id", ""))
	var result: Dictionary = manager.call("submit_audit_room_choice", remediation_id, choice) as Dictionary
	var ui: Dictionary = result.get("ui", {}) as Dictionary
	var feedback := str(ui.get("feedback", ""))
	if not bool(result.get("ok", false)):
		if feedback.strip_edges() == "":
			feedback = "Audit Room remediation failed: %s" % str(result.get("errors", []))
		if body_label:
			body_label.text = feedback
		return
	_render_review(feedback)

func _build_review_text(snapshot: Dictionary) -> String:
	var loop: Dictionary = snapshot.get("loop", {}) as Dictionary
	var financial: Dictionary = snapshot.get("financial", {}) as Dictionary
	var ledger: Dictionary = snapshot.get("ledger", {}) as Dictionary
	var contract_reviews: Dictionary = snapshot.get("contract_reviews", {}) as Dictionary
	var objectives: Dictionary = snapshot.get("objectives", {}) as Dictionary
	var remediation: Dictionary = snapshot.get("audit_room_remediation", {}) as Dictionary
	var balance_sheet: Dictionary = financial.get("balance_sheet", {}) as Dictionary

	var lines: Array[String] = []
	lines.append("Current Position")
	lines.append("- Week: %d" % int(loop.get("week_number", loop.get("week", 0))))
	lines.append("- Month: %d" % int(loop.get("month_number", loop.get("month", 1))))
	lines.append("- Cash: %s" % _format_currency(float(balance_sheet.get("cash", financial.get("cash", 0.0)))))
	lines.append("- Total Debt: %s" % _format_currency(_extract_total_debt(balance_sheet)))
	lines.append("- Audit Score: %d" % int(loop.get("audit_score", 0)))
	lines.append("- Ops Risk: %s" % _format_number(float(loop.get("ops_risk", 0.0))))
	lines.append("- Reputation: %s" % _format_number(float(loop.get("reputation", 0.0))))
	lines.append("- Points: %d" % int(loop.get("points", 0)))
	lines.append("")

	lines.append("Objectives")
	if objectives.is_empty():
		lines.append("- No objectives evaluated yet.")
	else:
		for key in objectives.keys():
			var result_value: Variant = objectives.get(key)
			if typeof(result_value) != TYPE_DICTIONARY:
				continue
			var result: Dictionary = result_value as Dictionary
			lines.append("- %s: %s | actual %s vs target %s | %s" % [
				str(result.get("id", key)),
				"PASSED" if bool(result.get("passed", false)) else "MISSED",
				_format_number(float(result.get("actual", 0.0))),
				_format_number(float(result.get("target", 0.0))),
				str(result.get("message", ""))
			])
	lines.append("")

	lines.append("Contract Review")
	if contract_reviews.is_empty():
		lines.append("- No contract review result stored.")
	else:
		for key in contract_reviews.keys():
			var review_value: Variant = contract_reviews.get(key)
			if typeof(review_value) != TYPE_DICTIONARY:
				continue
			var review: Dictionary = review_value as Dictionary
			lines.append("- %s" % str(key))
			lines.append("  Status: %s" % str(review.get("status", "unknown")))
			lines.append("  Risk Rating: %s" % str(review.get("risk_rating", "unknown")))
			lines.append("  Clawback Strength: %s" % str(review.get("clawback_strength", "unknown")))
			lines.append("  Minimum Service Commitment: %s" % ("Yes" if bool(review.get("minimum_service_commitment", false)) else "No"))
	lines.append("")

	lines.append("Ledger Trail")
	lines.append("- Transaction Count: %d" % int(ledger.get("transaction_count", 0)))
	var recent_value: Variant = ledger.get("recent_transactions", [])
	var recent_transactions: Array = []
	if typeof(recent_value) == TYPE_ARRAY:
		recent_transactions = recent_value as Array
	lines.append(_format_recent_transactions(recent_transactions))
	lines.append("")

	lines.append("Remediation Status")
	if remediation.is_empty():
		lines.append("- One remediation action available.")
	else:
		lines.append("- %s: %s" % [
			str(remediation.get("remediation_id", "remediation")),
			str(remediation.get("feedback", ""))
		])
	return "\n".join(PackedStringArray(lines))

func _format_recent_transactions(recent_transactions: Array) -> String:
	if recent_transactions.is_empty():
		return "- Recent Transactions: None"
	var lines: Array[String] = ["- Recent Transactions:"]
	for tx_value in recent_transactions:
		if typeof(tx_value) != TYPE_DICTIONARY:
			continue
		var tx: Dictionary = tx_value as Dictionary
		lines.append("  %s | %s | Week %s | %s" % [
			str(tx.get("tx_id", "tx")),
			str(tx.get("source", "ledger")),
			str(tx.get("week", "-")),
			str(tx.get("memo", ""))
		])
	return "\n".join(PackedStringArray(lines))

func _clear_dynamic_buttons() -> void:
	for button in _dynamic_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_dynamic_buttons.clear()

func _extract_total_debt(balance_sheet: Dictionary) -> float:
	if balance_sheet.has("total_debt"):
		return float(balance_sheet.get("total_debt", 0.0))
	return float(balance_sheet.get("short_term_debt", 0.0)) + float(balance_sheet.get("debt_term_loan", 0.0))

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
	return "%.1f" % value

func _on_close_pressed() -> void:
	visible = false
