extends CanvasLayer

@onready var body_label: Label = $PanelContainer/VBox/Body

func refresh(loop_snapshot: Dictionary, financial_snapshot: Dictionary) -> void:
	if body_label == null:
		return

	var week := int(loop_snapshot.get("week_number", loop_snapshot.get("week", 0)))
	var month := int(loop_snapshot.get("month_number", loop_snapshot.get("month", 1)))
	var cash := _extract_cash(financial_snapshot)
	var points := int(loop_snapshot.get("points", 0))
	var audit_score := int(loop_snapshot.get("audit_score", 0))
	var reputation := float(loop_snapshot.get("reputation", 0.0))
	var ops_risk := float(loop_snapshot.get("ops_risk", 0.0))
	var unlocks := _format_unlocks(loop_snapshot)

	body_label.text = (
		"Week: %d | Month: %d\n" % [week, month]
		+ "Cash: %s\n" % _format_currency(cash)
		+ "Points: %d\n" % points
		+ "Audit Score: %d\n" % audit_score
		+ "Reputation: %s\n" % _format_number(reputation)
		+ "Ops Risk: %s\n" % _format_number(ops_risk)
		+ "Unlocks: %s" % unlocks
	)

func _extract_cash(financial_snapshot: Dictionary) -> float:
	var balance_sheet: Dictionary = financial_snapshot.get("balance_sheet", {}) as Dictionary
	if balance_sheet.has("cash"):
		return float(balance_sheet.get("cash", 0.0))
	return float(financial_snapshot.get("cash", 0.0))

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
