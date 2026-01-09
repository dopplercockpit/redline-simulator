extends Node2D

const LOCKED_TOAST := "Locked in Patch 3A. Coming soon."

@onready var status_label: Label = $CanvasLayer/UIRoot/PanelContainer/VBox/Status
@onready var toast_label: Label = $CanvasLayer/UIRoot/ToastLabel
@onready var enter_hq_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/EnterHQ
@onready var boardroom_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/Boardroom
@onready var archives_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/Archives
@onready var coffee_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/Coffee

var _loop_system: Node = null

func _ready() -> void:
	_loop_system = get_node_or_null("/root/LoopSystem")
	_update_status()
	if _loop_system and _loop_system.has_signal("loop_updated"):
		if not _loop_system.loop_updated.is_connected(_on_loop_updated):
			_loop_system.loop_updated.connect(_on_loop_updated)
	enter_hq_button.pressed.connect(func() -> void: _goto("res://scenes/Hallway.tscn"))
	boardroom_button.pressed.connect(_show_locked)
	archives_button.pressed.connect(_show_locked)
	coffee_button.pressed.connect(_show_locked)

func _get_loop_snapshot() -> Dictionary:
	if _loop_system and _loop_system.has_method("get_snapshot"):
		var snap: Variant = _loop_system.call("get_snapshot")
		if typeof(snap) == TYPE_DICTIONARY:
			return snap
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_loop_snapshot"):
		var snap: Variant = gm.call("get_loop_snapshot")
		if typeof(snap) == TYPE_DICTIONARY:
			return snap
	return {}

func _update_status() -> void:
	var snap := _get_loop_snapshot()
	var week_text := "?"
	var month_text := "?"
	if snap.has("week_number"):
		week_text = str(snap.get("week_number"))
	elif snap.has("week"):
		week_text = str(snap.get("week"))
	if snap.has("month_number"):
		month_text = str(snap.get("month_number"))
	elif snap.has("month"):
		month_text = str(snap.get("month"))
	if status_label:
		status_label.text = "Week %s | Month %s" % [week_text, month_text]

func _on_loop_updated(_snapshot: Dictionary) -> void:
	_update_status()

func _show_locked() -> void:
	if toast_label:
		toast_label.text = LOCKED_TOAST
		toast_label.visible = true

func _goto(path: String) -> void:
	get_tree().call_deferred("change_scene_to_file", path)
