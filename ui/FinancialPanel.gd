extends CanvasLayer

signal commentary_submitted(text)

@onready var income_grid: GridContainer   = $PanelContainer/ScrollContainer/VBoxContainer/IncomeGrid
@onready var balance_grid: GridContainer  = $PanelContainer/ScrollContainer/VBoxContainer/BalanceGrid
@onready var cash_grid: GridContainer     = $PanelContainer/ScrollContainer/VBoxContainer/CashGrid
@onready var commentary_input: TextEdit   = $PanelContainer/ScrollContainer/VBoxContainer/CommentaryInput
@onready var submit_button: Button        = $PanelContainer/ScrollContainer/VBoxContainer/SubmitButton
@onready var scroll_container: ScrollContainer = $PanelContainer/ScrollContainer

@onready var student_name: LineEdit = get_node_or_null(
	"PanelContainer/ScrollContainer/VBoxContainer/NameRow/StudentName"
) as LineEdit

var close_button: Button

var income_lines: Array = [
	["landing_fees_revenue", "Landing Fees Revenue"],
	["passenger_facility_charges_revenue", "Passenger Facility Charges Revenue"],
	["concessions_revenue", "Concessions Revenue"],
	["total_operating_revenue", "Total Operating Revenue"],
	["payroll_expense", "Payroll Expense"],
	["utilities_expense", "Utilities Expense"],
	["interest_expense", "Interest Expense"],
	["total_operating_expense", "Total Operating Expense"],
	["operating_surplus", "Operating Surplus"]
]

var balance_lines: Array = [
	["cash", "Cash"],
	["accounts_receivable", "Accounts Receivable"],
	["deferred_revenue", "Deferred Revenue"],
	["accounts_payable", "Accounts Payable"],
	["accrued_expenses", "Accrued Expenses"],
	["debt_term_loan", "Debt - Term Loan"],
	["retained_earnings", "Retained Earnings / Net Position"],
	["total_assets", "Total Assets"],
	["total_liabilities", "Total Liabilities"],
	["equity", "Equity / Net Position"],
	["liabilities_and_equity", "Liabilities + Equity"]
]

var cash_lines: Array = [
	["operating_cash_flow", "Cash Flow from Operations"],
	["investing_cash_flow", "Cash Flow from Investing Activities"],
	["financing_cash_flow", "Cash Flow from Financing Activities"],
	["net_change_in_cash", "Net Change in Cash"],
	["ending_cash", "Ending Cash Balance"]
]

func _ready() -> void:
	close_button = get_node_or_null("PanelContainer/ScrollContainer/VBoxContainer/Close") as Button
	if close_button == null:
		close_button = get_node_or_null("PanelContainer/ScrollContainer/VBoxContainer/CloseButton") as Button

	# Ensure student_name is found even if there's no NameRow container
	if student_name == null:
		student_name = get_node_or_null(
			"PanelContainer/ScrollContainer/VBoxContainer/StudentName"
		) as LineEdit

	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	var vsb: VScrollBar = scroll_container.get_v_scroll_bar()
	if vsb:
		vsb.visible = true
		vsb.custom_minimum_size = Vector2(10, 0)
		vsb.add_theme_constant_override("thickness", 10)

func get_student_name() -> String:
	return student_name.text.strip_edges() if student_name != null else ""

func update_display(data: Dictionary) -> void:
	show_financials(data)

func reset_for_next_scenario() -> void:
	if commentary_input:
		commentary_input.text = ""
	if submit_button:
		submit_button.text = "Submit Analysis"

func set_submission_enabled(enabled: bool) -> void:
	if submit_button == null:
		return
	submit_button.disabled = not enabled
	submit_button.text = "Submit Analysis" if enabled else "Submit (Month End Only)"

func show_financials(data: Dictionary) -> void:
	var isec: Variant = _find_section(data, ["income_statement","incomeStatement","income","is"])
	var bsec: Variant = _find_section(data, ["balance_sheet","balanceSheet","balance","bs"])
	var csec: Variant = _find_section(data, ["cash_flow","cashflow","cashFlow","cash","cf"])

	_populate_grid_dynamic(income_grid,  isec if isec != null else {}, income_lines)
	_populate_grid_dynamic(balance_grid, bsec if bsec != null else {}, balance_lines)
	_populate_grid_dynamic(cash_grid,    csec if csec != null else {}, cash_lines)
	commentary_input.grab_focus()

func _find_section(root: Dictionary, keys: Array) -> Variant:
	for k in keys:
		if root.has(k):
			return _unwrap_section(root[k])

	if root.has("sections") and typeof(root["sections"]) == TYPE_ARRAY:
		for s in root["sections"]:
			if typeof(s) == TYPE_DICTIONARY:
				var t := str(s.get("type","")).to_lower()
				for k in keys:
					if t.begins_with(str(k).to_lower()):
						return _unwrap_section(s.get("data", s))
	return null

func _unwrap_section(sec: Variant) -> Variant:
	if typeof(sec) == TYPE_DICTIONARY:
		var d: Dictionary = sec
		if d.has("lines"): return d["lines"]
		if d.has("items"): return d["items"]
		if d.has("rows"):  return d["rows"]
		if d.has("data"):  return d["data"]
	return sec

func _populate_grid_dynamic(grid: GridContainer, src: Variant, order: Array) -> void:
	# Clear existing children
	while grid.get_child_count() > 0:
		var n: Node = grid.get_child(0)
		grid.remove_child(n)
		n.queue_free()

	# Handle Dictionary source
	if typeof(src) == TYPE_DICTIONARY:
		var dict: Dictionary = src
		var hits := 0
		# Try to match keys from the order array
		for pair in order:
			var key: String = pair[0]
			var label_text: String = pair[1]
			if dict.has(key):
				_add_row(grid, label_text, dict.get(key, 0))
				hits += 1

		# If no matches, just dump all keys
		if hits == 0:
			for k in dict.keys():
				_add_row(grid, str(k), dict[k])
		return

	# Handle Array source
	if typeof(src) == TYPE_ARRAY:
		for item in (src as Array):
			if typeof(item) == TYPE_ARRAY and item.size() >= 2:
				_add_row(grid, str(item[0]), item[1])
			elif typeof(item) == TYPE_DICTIONARY:
				var dict := item as Dictionary
				var lbl: String = str(dict.get("label", ""))
				var val: Variant = dict["value"] if dict.has("value") else null
				if lbl == "" and dict.size() > 0:
					var keys: Array = dict.keys()
					var k: String = str(keys[0])
					lbl = k
					val = dict[k]
				_add_row(grid, lbl, val)
		return

func _add_row(grid: GridContainer, left_text: String, right_val: Variant) -> void:
	var l := Label.new()
	l.text = left_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := Label.new()
	r.text = _fmt(right_val)
	grid.add_child(l)
	grid.add_child(r)

func _fmt(v) -> String:
	match typeof(v):
		TYPE_INT:
			return "%d" % v
		TYPE_FLOAT:
			return "%d" % int(round(v))
		TYPE_STRING:
			return v
		TYPE_NIL:
			return "-"
		_:
			return str(v)

func _on_submit_pressed() -> void:
	var txt: String = commentary_input.text.strip_edges() if commentary_input != null else ""
	if txt.is_empty():
		txt = "(empty commentary)"
	emit_signal("commentary_submitted", txt)
	if submit_button:
		submit_button.disabled = true
		submit_button.text = "Submitted"

func _on_close_pressed() -> void:
	visible = false

# Example helper function for the active Airport CFO statement shape.
func get_financial_summary_example() -> Dictionary:
	return {
		"income_statement": {
			"landing_fees_revenue": 0.0,
			"passenger_facility_charges_revenue": 0.0,
			"concessions_revenue": 0.0,
			"total_operating_revenue": 0.0,
			"payroll_expense": 0.0,
			"utilities_expense": 0.0,
			"interest_expense": 0.0,
			"total_operating_expense": 0.0,
			"operating_surplus": 0.0
		},
		"balance_sheet": {
			"cash": 0.0,
			"accounts_receivable": 0.0,
			"accounts_payable": 0.0,
			"equity": 0.0
		},
		"cash_flow": {
			"operating_cash_flow": 0.0,
			"net_change_in_cash": 0.0,
			"ending_cash": 0.0
		}
	}
