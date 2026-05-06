extends CanvasLayer

@onready var body_label: RichTextLabel = $PanelContainer/ScrollContainer/VBox/Body
@onready var smoke_button: Button = $PanelContainer/ScrollContainer/VBox/RunSmokeTest
@onready var fresh_button: Button = $PanelContainer/ScrollContainer/VBox/FreshStart
@onready var month1_button: Button = $PanelContainer/ScrollContainer/VBox/Month1Complete
@onready var month2_button: Button = $PanelContainer/ScrollContainer/VBox/Month2Complete
@onready var month3_button: Button = $PanelContainer/ScrollContainer/VBox/Month3Complete
@onready var full_button: Button = $PanelContainer/ScrollContainer/VBox/FullDemoComplete
@onready var export_button: Button = $PanelContainer/ScrollContainer/VBox/ExportSummary
@onready var close_button: Button = $PanelContainer/ScrollContainer/VBox/Close

func _ready() -> void:
	visible = false
	_connect_button(smoke_button, _on_smoke_pressed)
	_connect_button(fresh_button, _on_demo_target_pressed.bind("fresh_start"))
	_connect_button(month1_button, _on_demo_target_pressed.bind("month1_complete"))
	_connect_button(month2_button, _on_demo_target_pressed.bind("month2_complete"))
	_connect_button(month3_button, _on_demo_target_pressed.bind("month3_complete"))
	_connect_button(full_button, _on_demo_target_pressed.bind("full_demo_complete"))
	_connect_button(export_button, _on_export_pressed)
	_connect_button(close_button, _on_close_pressed)

func open_panel() -> void:
	visible = true
	_set_body("Demo and QA tools are local fixtures for testing and instruction.\n\nUse smoke test first, then jump to a target state.")

func _on_smoke_pressed() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("run_smoke_test"):
		_set_body("GameManager unavailable.")
		return
	var result: Dictionary = manager.call("run_smoke_test") as Dictionary
	_set_body(_format_smoke_result(result))

func _on_demo_target_pressed(target: String) -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("apply_demo_state"):
		_set_body("GameManager unavailable.")
		return
	var result: Dictionary = manager.call("apply_demo_state", target) as Dictionary
	if bool(result.get("ok", false)):
		_set_body("Applied demo target: %s\nSaved current demo state." % target)
	else:
		_set_body("Demo target failed: %s\n%s" % [target, str(result.get("errors", []))])

func _on_export_pressed() -> void:
	var manager := _manager()
	if manager == null or not manager.has_method("export_run_summary"):
		_set_body("GameManager unavailable.")
		return
	var result: Dictionary = manager.call("export_run_summary") as Dictionary
	if bool(result.get("ok", false)):
		_set_body("Export complete.\nPath: %s" % str(result.get("path", "")))
	else:
		_set_body("Export failed.\n%s" % str(result.get("errors", [])))

func _on_close_pressed() -> void:
	visible = false

func _format_smoke_result(result: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Smoke Test: %s" % ("PASS" if bool(result.get("ok", false)) else "FAIL"))
	lines.append("")
	var checks_value: Variant = result.get("checks", [])
	if typeof(checks_value) == TYPE_ARRAY:
		var checks: Array = checks_value as Array
		for check_value in checks:
			if typeof(check_value) != TYPE_DICTIONARY:
				continue
			var check: Dictionary = check_value as Dictionary
			lines.append("%s %s - %s" % [
				"PASS" if bool(check.get("ok", false)) else "FAIL",
				str(check.get("id", "check")),
				str(check.get("message", ""))
			])
	var errors: Array = result.get("errors", []) as Array
	if not errors.is_empty():
		lines.append("")
		lines.append("Errors:")
		for error in errors:
			lines.append("- %s" % str(error))
	return "\n".join(PackedStringArray(lines))

func _connect_button(button: Button, callable: Callable) -> void:
	if button and not button.pressed.is_connected(callable):
		button.pressed.connect(callable)

func _set_body(text: String) -> void:
	if body_label:
		body_label.text = text

func _manager() -> Node:
	return get_node_or_null("/root/GameManager")
