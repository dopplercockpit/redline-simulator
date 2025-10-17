extends CanvasLayer

signal commentary_submitted(text)

@onready var income_grid: GridContainer   = $PanelContainer/ScrollContainer/VBoxContainer/IncomeGrid
@onready var balance_grid: GridContainer  = $PanelContainer/ScrollContainer/VBoxContainer/BalanceGrid
@onready var cash_grid: GridContainer     = $PanelContainer/ScrollContainer/VBoxContainer/CashGrid
@onready var close_button: Button         = $PanelContainer/ScrollContainer/VBoxContainer/CloseButton
@onready var commentary_input: TextEdit   = $PanelContainer/ScrollContainer/VBoxContainer/CommentaryInput
@onready var submit_button: Button        = $PanelContainer/ScrollContainer/VBoxContainer/SubmitButton
@onready var student_name: LineEdit       = $PanelContainer/ScrollContainer/VBoxContainer/NameRow/StudentName
@onready var scroll_container: ScrollContainer = $PanelContainer/ScrollContainer

# Display order / labels
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
	submit_button.pressed.connect(_on_submit_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Make scrollbar visible/chunky for demo
	var vsb: VScrollBar = scroll_container.get_v_scroll_bar()
	vsb.visible = true
	vsb.custom_minimum_size = Vector2(10, 0)
	vsb.add_theme_constant_override("thickness", 10)

func get_student_name() -> String:
	return student_name.text.strip_edges()

func reset_for_next_scenario() -> void:
	commentary_input.text = ""
	submit_button.disabled = false
	submit_button.text = "Submit Analysis"
	# keep name as-is so they don't retype each round

func show_financials(data: Dictionary) -> void:
	# expects keys: income_statement, balance_sheet, cash_flow
	if not data.has("income_statement"): return
	if not data.has("balance_sheet"): return
	if not data.has("cash_flow"): return

	_populate_grid(income_grid, data["income_statement"], income_lines)
	_populate_grid(balance_grid, data["balance_sheet"], balance_lines)
	_populate_grid(cash_grid, data["cash_flow"], cash_lines)

func _populate_grid(grid: GridContainer, src: Dictionary, order: Array) -> void:
	for i in range(0, grid.get_child_count()):
		var node := grid.get_child(i)
		if node is Label:
			node.text = ""

	var row := 0
	for pair in order:
		var key: String = pair[0]
		var label_text: String = pair[1]
		var value: Variant = src.get(key, 0)
		var left: Label = grid.get_child(row * 2)
		var right: Label = grid.get_child(row * 2 + 1)
		left.text = label_text
		right.text = _fmt(value)
		row += 1

func _fmt(v) -> String:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return "%d" % int(v)
	return str(v)

func _on_submit_pressed() -> void:
	var txt: String = commentary_input.text.strip_edges()
	if txt.is_empty():
		txt = "(empty commentary)"
	emit_signal("commentary_submitted", txt)
	submit_button.disabled = true
	submit_button.text = "Submitted"

func _on_close_pressed() -> void:
	var txt: String = commentary_input.text.strip_edges()
