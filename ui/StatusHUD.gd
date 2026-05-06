extends CanvasLayer

@onready var body_label: Label = $PanelContainer/VBox/Body

func refresh(loop_snapshot: Dictionary, financial_snapshot: Dictionary) -> void:
	if body_label == null:
		return

	var week := int(loop_snapshot.get("week_number", loop_snapshot.get("week", 0)))
	var month := int(loop_snapshot.get("month_number", loop_snapshot.get("month", 1)))
	var cash := _extract_cash(financial_snapshot)
	var total_debt := _extract_total_debt(financial_snapshot)
	var points := int(loop_snapshot.get("points", 0))
	var audit_score := int(loop_snapshot.get("audit_score", 0))
	var reputation := float(loop_snapshot.get("reputation", 0.0))
	var ops_risk := float(loop_snapshot.get("ops_risk", 0.0))
	var unlocks := _format_unlocks(loop_snapshot)
	var save_status := _format_save_status()

	body_label.text = (
		"Week: %d | Month: %d\n" % [week, month]
		+ "Cash: %s\n" % _format_currency(cash)
		+ "Total Debt: %s\n" % _format_currency(total_debt)
		+ "Points: %d\n" % points
		+ "Audit Score: %d\n" % audit_score
		+ "Reputation: %s\n" % _format_number(reputation)
		+ "Ops Risk: %s\n" % _format_number(ops_risk)
		+ "Unlocks: %s%s%s" % [
			unlocks,
			_format_contract_review_done(loop_snapshot),
			_format_audit_room_done(loop_snapshot)
		]
		+ "\nSave: %s" % save_status
		+ _format_demo_mode(loop_snapshot)
	)

func _extract_cash(financial_snapshot: Dictionary) -> float:
	var balance_sheet: Dictionary = financial_snapshot.get("balance_sheet", {}) as Dictionary
	if balance_sheet.has("cash"):
		return float(balance_sheet.get("cash", 0.0))
	return float(financial_snapshot.get("cash", 0.0))

func _extract_total_debt(financial_snapshot: Dictionary) -> float:
	var balance_sheet: Dictionary = financial_snapshot.get("balance_sheet", {}) as Dictionary
	if balance_sheet.has("total_debt"):
		return float(balance_sheet.get("total_debt", 0.0))
	return (
		float(balance_sheet.get("short_term_debt", 0.0))
		+ float(balance_sheet.get("debt_term_loan", 0.0))
	)

func _format_unlocks(loop_snapshot: Dictionary) -> String:
	var names: Array[String] = []
	var flags: Dictionary = loop_snapshot.get("flags", {}) as Dictionary
	if bool(flags.get("cap.inbox", false)):
		names.append("Inbox")

	var unlocks: Dictionary = loop_snapshot.get("unlocks", {}) as Dictionary
	for key in unlocks.keys():
		if bool(unlocks.get(key, false)):
			names.append(str(key))

	if names.is_empty():
		return "None"
	return ", ".join(PackedStringArray(names))

func _format_contract_review_done(loop_snapshot: Dictionary) -> String:
	var flags: Dictionary = loop_snapshot.get("flags", {}) as Dictionary
	if bool(flags.get("contract_review_completed.BUDGETAIR_INCENTIVE_REVIEW", false)):
		return "\nContract Review: Done"
	return ""

func _format_audit_room_done(loop_snapshot: Dictionary) -> String:
	var flags: Dictionary = loop_snapshot.get("flags", {}) as Dictionary
	if bool(flags.get("tool_used.AUDIT_ROOM", false)):
		return "\nAudit Room: Remediated"
	return ""

func _format_save_status() -> String:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("has_saved_run"):
		return "Available" if bool(manager.call("has_saved_run")) else "Unsaved"
	return "Unknown"

func _format_demo_mode(loop_snapshot: Dictionary) -> String:
	var flags: Dictionary = loop_snapshot.get("flags", {}) as Dictionary
	if not bool(flags.get("demo_mode", false)):
		return ""
	var memory: Dictionary = loop_snapshot.get("memory", {}) as Dictionary
	return "\nDEMO MODE: %s" % str(memory.get("demo_target", "demo"))

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
