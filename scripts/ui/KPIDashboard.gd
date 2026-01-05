extends Control

@export var RowScene: PackedScene
@onready var grid: GridContainer = $GridContainer

func _on_state_updated(state: Dictionary) -> void:
	var pnl: Dictionary = state.get("financial_statements", {}).get("income_statement", {})
	var lines: Array = pnl.get("lines", [])

	for child in grid.get_children():
		child.queue_free()

	if RowScene == null:
		push_warning("KPIDashboard RowScene is not assigned")
		return

	for line in lines:
		var row = RowScene.instantiate()
		if row.has_method("set_label"):
			row.set_label(line.get("label", ""))
		if row.has_method("set_value"):
			row.set_value(line.get("value", 0))
		if row.has_method("set_style") and line.has("type"):
			row.set_style(line["type"])
		if row.has_method("set_tooltip") and line.has("lever_hint"):
			row.set_tooltip(line["lever_hint"])
		grid.add_child(row)
