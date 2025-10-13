extends CanvasLayer

@onready var income_grid = $PanelContainer/VBoxContainer/IncomeGrid
@onready var balance_grid = $PanelContainer/VBoxContainer/BalanceGrid
@onready var cash_grid = $PanelContainer/VBoxContainer/CashGrid
@onready var close_button = $PanelContainer/VBoxContainer/CloseButton

# templates for ordering and labels
var income_lines = [
	["gross_sales", "Gross Sales"],
	["promo_allowances", "Promotional Allowances"],
	["customer_allowances", "Customer / Distributor Allowances"],
	["net_sales", "Net Sales Revenue"],
	["materials_cost", "Materials"],
	["labor_cost", "Labor"],
	["overhead_cost", "Overhead"],
	["total_cogs", "Total COGS"],
	["gross_profit", "Gross Profit"],
	["marketing_expense", "Marketing Expense"],
	["sga_expense", "SG&A Expense"],
	["depreciation", "Depreciation"],
	["ebit", "EBIT"],
	["interest_expense", "Interest Expense"],
	["net_income", "Net Income"]
]

var balance_lines = [
	["cash", "Cash"],
	["accounts_receivable", "Accounts Receivable"],
	["inventory_raw", "Inventory - Raw"],
	["inventory_wip", "Inventory - WIP"],
	["inventory_fg", "Inventory - Finished Goods"],
	["total_inventory", "Total Inventory"],
	["ppe", "Property, Plant & Equipment"],
	["total_assets", "Total Assets"],
	["accounts_payable", "Accounts Payable"],
	["current_debt", "Current Portion of Debt"],
	["total_debt", "Total Debt"],
	["equity", "Equity"],
	["total_liab_equity", "Total Liabilities + Equity"]
]

var cash_lines = [
	["net_income", "Net Income"],
	["change_working_capital", "Change in Working Capital"],
	["capex", "Capital Expenditures"],
	["debt_activity", "Debt Activity"],
	["equity_activity", "Equity Activity"],
	["net_change_cash", "Net Change in Cash"],
	["ending_cash", "Ending Cash Balance"]
]


func _ready():
	close_button.connect("pressed", Callable(self, "_on_close_pressed"))
	visible = false


func show_financials(data: Dictionary) -> void:
	if not data.has("income_statement"): return
	visible = true
	_populate_grid(income_grid, data["income_statement"], income_lines)
	_populate_grid(balance_grid, data["balance_sheet"], balance_lines)
	_populate_grid(cash_grid, data["cash_flow"], cash_lines)


func _populate_grid(grid: GridContainer, values: Dictionary, layout: Array) -> void:
	for c in grid.get_children():
		c.queue_free()

	for pair in layout:
		var key = pair[0]
		var label_text = pair[1]
		var value = ""
		if values.has(key):
			value = _fmt(values[key])
		else:
			value = "-"
		var label_left = Label.new()
		label_left.text = label_text
		label_left.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		var label_right = Label.new()
		label_right.text = value
		label_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_right.add_theme_color_override("font_color", Color(1, 1, 1))
		grid.add_child(label_left)
		grid.add_child(label_right)


func _fmt(v) -> String:
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return "%s" % String.num(v, 0)  # no decimals
	else:
		return str(v)


func _on_close_pressed():
	visible = false
