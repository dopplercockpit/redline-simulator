extends CanvasLayer

signal commentary_submitted(text)

@onready var income_grid: GridContainer   = $PanelContainer/ScrollContainer/VBoxContainer/IncomeGrid
@onready var balance_grid: GridContainer  = $PanelContainer/ScrollContainer/VBoxContainer/BalanceGrid
@onready var cash_grid: GridContainer     = $PanelContainer/ScrollContainer/VBoxContainer/CashGrid
@onready var commentary_input: TextEdit   = $PanelContainer/ScrollContainer/VBoxContainer/CommentaryInput
@onready var submit_button: Button        = $PanelContainer/ScrollContainer/VBoxContainer/SubmitButton
@onready var scroll_container: ScrollContainer = $PanelContainer/ScrollContainer

# Name input (robust: with or without NameRow wrapper)
@onready var student_name: LineEdit = (
	get_node_or_null("PanelContainer/ScrollContainer/VBoxContainer/NameRow/StudentName") as LineEdit
) if get_node_or_null("PanelContainer/ScrollContainer/VBoxContainer/NameRow/StudentName") != null else (
	get_node("PanelContainer/ScrollContainer/VBoxContainer/StudentName") as LineEdit
)

var close_button: Button  # resolved in _ready

var income_lines: Array = [
	["gross_sales", "Gross Sales"],
	["promo_allowances", "Promotional Allowances"],
	["net_sales", "Net Sales"],
	["cogs", "COGS"],
	["gross_margin", "Gross Margin"],
	["opex", "Operating Expenses"],
	["ebit", "EBIT"]
]

var balance_lines: Array = [
	["inventory_wip", "Inventory - WIP"],
	["inventory_fg", "Inventory - Finished Goods"],
	["total_inventory", "Total Inventory"],
	["ppe", "Property, Plant & Equipment"],
	["total_assets", "Total Assets"],
	["ap", "Accounts Payable"],
	["current_debt", "Current Portion of Debt"],
	["total_debt", "Total Debt"],
	["equity", "Equity"],
	["liab_plus_equity", "Total Liabilities + Equity"]
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
	# Find Close node whether it's named Close or CloseButton
	close_button = get_node_or_null("PanelContainer/ScrollContainer/VBoxContainer/Close") as Button
	if close_button == null:
		close_button = get_node_or_null("PanelContainer/ScrollContainer/VBoxContainer/CloseButton") as Button

	# Wire buttons (guarded)
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	# Make scrollbar obvious (guard: can be null at ready)
	var vsb: VScrollBar = scroll_container.get_v_scroll_bar()
	if vsb:
		vsb.visible = true
		vsb.custom_minimum_size = Vector2(10, 0)
		vsb.add_theme_constant_override("thickness", 10)

func get_student_name() -> String:
	return student_name.text.strip_edges() if student_name else ""

func reset_for_next_scenario() -> void:
	if commentary_input:
		commentary_input.text = ""
	if submit_button:
		submit_button.disabled = false
		submit_button.text = "Submit Analysis"

func show_financials(data: Dictionary) -> void:
	# Accept multiple naming schemes and both Array/Dictionary payloads.
	var isec: Variant = _find_section(data, ["income_statement","incomeStatement","income","is"])
	var bsec: Variant = _find_section(data, ["balance_sheet","balanceSheet","balance","bs"])
	var csec: Variant = _find_section(data, ["cash_flow","cashflow","cashFlow","cash","cf"])

	# Render even if a section is missing (don’t leave the UI empty)
	_populate_grid_dynamic(income_grid,  isec if isec != null else {}, income_lines)
	_populate_grid_dynamic(balance_grid, bsec if bsec != null else {}, balance_lines)
	_populate_grid_dynamic(cash_grid,    csec if csec != null else {}, cash_lines)
	commentary_input.grab_focus()

func _find_section(root: Dictionary, keys: Array) -> Variant:
	# Direct hit on any of the provided key names
	for k in keys:
		if root.has(k):
			return _unwrap_section(root[k])

	# Sometimes data comes as an array of sections with "type" and inner payload
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
	if grid == null:
		return
	grid.columns = 2

	# Clear children safely
	while grid.get_child_count() > 0:
		var n: Node = grid.get_child(0)
		grid.remove_child(n)
		n.queue_free()

	# 1) Dictionary path
	if typeof(src) == TYPE_DICTIONARY:
		var dict: Dictionary = src

		# Use canonical order if we can match any keys
		var hits := 0
		for pair in order:
			var key: String = pair[0]
			var label_text: String = pair[1]
			if dict.has(key):
				_add_row(grid, label_text, dict.get(key, 0))
				hits += 1

		# If we matched nothing, just iterate keys (better than zeros)
		if hits == 0:
			for k in dict.keys():
				_add_row(grid, str(k), dict[k])
		return

	# 2) Array path: ["Label", value] or {label,value} or first k/v
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

# func _populate_grid_dynamic(grid: GridContainer, src: Variant, order: Array) -> void:
#	if grid == null:
#		return
#	grid.columns = 2

	# Clear children safely
	while grid.get_child_count() > 0:
		var n: Node = grid.get_child(0)
		grid.remove_child(n)
		n.queue_free()

	# Dictionary path (use provided order)
	if typeof(src) == TYPE_DICTIONARY:
		for pair in order:
			var key: String = pair[0]
			var label_text: String = pair[1]
			_add_row(grid, label_text, (src as Dictionary).get(key, 0))
		return

	# Array path (either ["Label", value] or {label,value} or first kv)
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
	var txt: String = commentary_input.text.strip_edges() if commentary_input else ""
	if txt.is_empty():
		txt = "(empty commentary)"
	emit_signal("commentary_submitted", txt)
	if submit_button:
		submit_button.disabled = true
		submit_button.text = "Submitted"

func _on_close_pressed() -> void:
	visible = false
