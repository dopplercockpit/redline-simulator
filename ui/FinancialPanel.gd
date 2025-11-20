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
	["ticket_rev", "Passenger Revenue"],
	["ancillary_rev", "Ancillary Revenue (Bags/Seats)"],
	["total_rev", "Total Revenue"],
	["fuel_costs", "Fuel Costs"],
	["crew_costs", "Crew & Salaries"],
	["airport_fees", "Landing & Navigation Fees"],
	["maintenance", "MRO (Maintenance)"],
	["leasing_costs", "Aircraft Leases"],
	["ebitdar", "EBITDAR"],
	["net_income", "Net Income"]
]

var balance_lines: Array = [
	["cash", "Cash & Equivalents"],
	["receivables", "Accounts Receivable (OTA/Credit Cards)"],
	["rotable_parts", "Spare Parts Inventory"],
	["flight_equipment", "Flight Equipment (Owned)"],
	["rou_assets", "Right-of-Use Assets (Leased Planes)"],
	["total_assets", "Total Assets"],
	["accounts_payable", "Accounts Payable"],
	["air_traffic_liab", "Unearned Revenue (Future Flights)"],
	["lease_liabilities", "Lease Liabilities"],
	["long_term_debt", "Long Term Debt"],
	["equity", "Shareholder Equity"]
]

var cash_lines: Array = [
	["net_income", "Net Income"],
	["change_in_working_capital", "Change in Working Capital"],
	["capex", "Capital Expenditures"],
	["debt_activity", "Debt Activity"],
	["equity_activity", "Equity Activity"],
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
	return student_name != null ? student_name.text.strip_edges() : ""

func update_display(data: Dictionary) -> void:
	show_financials(data)

func reset_for_next_scenario() -> void:
	if commentary_input:
		commentary_input.text = ""
	if submit_button:
		submit_button.disabled = false
		submit_button.text = "Submit Analysis"

func show_financials(data: Dictionary) -> void:
	var isec: Variant = _find_section(data, ["income_statement","incomeStatement","income","is"])
	var bsec: Variant = _find_section(data, ["balance_sheet","balanceSheet","balance","bs"])
	var csec: Variant = _find_section(data, ["cash_flow","cashflow","cashFlow","cash","cf"])

	_populate_grid_dynamic(income_grid,  isec != null ? isec : {}, income_lines)
	_populate_grid_dynamic(balance_grid, bsec != null ? bsec : {}, balance_lines)
	_populate_grid_dynamic(cash_grid,    csec != null ? csec : {}, cash_lines)
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

	while grid.get_child_count() > 0:
		var n: Node = grid.get_child(0)
		grid.remove_child(n)
		n.queue_free()

	if typeof(src) == TYPE_DICTIONARY:
		var dict: Dictionary = src
		var hits := 0
		for pair in order:
			var key: String = pair[0]
			var label_text: String = pair[1]
			if dict.has(key):
				_add_row(grid, label_text, dict.get(key, 0))
				hits += 1

		if hits == 0:
			for k in dict.keys():
				_add_row(grid, str(k), dict[k])
		return

	if typeof(src) == TYPE_ARRAY:
		for item in (src as Array):
			if typeof(item) == TYPE_ARRAY and item.size() >= 2:
				_add_row(grid, str(item[0]), item[1])
			elif typeof(item) == TYPE_DICTIONARY:
				var dict := item as Dictionary
				var lbl: String = str(dict.get("label", ""))
				var val: Variant = dict.has("value") ? dict["value"] : null
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
	var txt: String = commentary_input != null ? commentary_input.text.strip_edges() : ""
	if txt.is_empty():
		txt = "(empty commentary)"
	emit_signal("commentary_submitted", txt)
	if submit_button:
		submit_button.disabled = true
		submit_button.text = "Submitted"

func _on_close_pressed() -> void:
	visible = false

# res://engine/state.gd

# ... existing variables ...

# Calculate financial summary on the fly based on operational state
func get_financial_summary() -> Dictionary:
	var monthly_lease_cost = 0.0
	for plane_type in fleet:
		var p = fleet[plane_type]
		monthly_lease_cost += p["count"] * p["lease_usd_mpm"]

	var monthly_fuel_cost = 0.0 # You would calculate this based on routes * distance * fuel price
	
	# Return the dictionary structured for the FinancialPanel
	return {
		"income_statement": {
			"ticket_rev": revenue_ytd, # Placeholder, replace with actual logic
			"ancillary_rev": revenue_ytd * 0.15, # Assumption: 15% upsell
			"total_rev": revenue_ytd * 1.15,
			"leasing_costs": monthly_lease_cost,
			"fuel_costs": monthly_fuel_cost,
			# ... fill in other calculated fields ...
		},
		"balance_sheet": {
			"cash": cash,
			"rou_assets": monthly_lease_cost * 12 * 5, # Rough valuation of leased planes
			"equity": cash - 50000 # Simplified equity logic
		}
	}
