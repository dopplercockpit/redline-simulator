extends CanvasLayer

@onready var body_label: RichTextLabel = $PanelContainer/VBox/Body
@onready var save_button: Button = $PanelContainer/VBox/SaveRun
@onready var load_button: Button = $PanelContainer/VBox/LoadRun
@onready var export_button: Button = $PanelContainer/VBox/ExportSummary
@onready var reset_button: Button = $PanelContainer/VBox/ResetRun
@onready var close_button: Button = $PanelContainer/VBox/Close

func _ready() -> void:
	visible = false
	if save_button and not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)
	if load_button and not load_button.pressed.is_connected(_on_load_pressed):
		load_button.pressed.connect(_on_load_pressed)
	if export_button and not export_button.pressed.is_connected(_on_export_pressed):
		export_button.pressed.connect(_on_export_pressed)
	if reset_button and not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func open_menu() -> void:
	visible = true
	_refresh_body("Choose a local run action.")

func _on_save_pressed() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("save_run"):
		_refresh_body("GameManager unavailable.")
		return
	var result: Dictionary = manager.call("save_run") as Dictionary
	_refresh_body(_format_result("Save Run", result))

func _on_load_pressed() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("load_run"):
		_refresh_body("GameManager unavailable.")
		return
	var result: Dictionary = manager.call("load_run") as Dictionary
	_refresh_body(_format_result("Load Run", result))

func _on_export_pressed() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("export_run_summary"):
		_refresh_body("GameManager unavailable.")
		return
	var result: Dictionary = manager.call("export_run_summary") as Dictionary
	_refresh_body(_format_result("Export Summary", result))

func _on_reset_pressed() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("reset_run"):
		_refresh_body("GameManager unavailable.")
		return
	var result: Dictionary = manager.call("reset_run") as Dictionary
	_refresh_body(_format_result("Reset Run", result))

func _on_close_pressed() -> void:
	visible = false

func _manager() -> Node:
	return get_node_or_null("/root/GameManager")

func _refresh_body(message: String) -> void:
	if body_label == null:
		return
	var manager := _manager()
	var save_path := "user://flightpath_run_save.json"
	var export_path := "user://flightpath_run_summary.md"
	var has_save := false
	if manager:
		if manager.has_method("get_save_path"):
			save_path = str(manager.call("get_save_path"))
		if manager.has_method("get_export_path"):
			export_path = str(manager.call("get_export_path"))
		if manager.has_method("has_saved_run"):
			has_save = bool(manager.call("has_saved_run"))
	body_label.text = (
		"%s\n\n" % message
		+ "Save: %s\n" % ("Available" if has_save else "None yet")
		+ "Save path: %s\n" % save_path
		+ "Export path: %s" % export_path
	)

func _format_result(label: String, result: Dictionary) -> String:
	if bool(result.get("ok", false)):
		return "%s complete.\nPath: %s" % [label, str(result.get("path", ""))]
	return "%s failed.\n%s" % [label, str(result.get("errors", []))]
