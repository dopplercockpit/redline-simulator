extends Node2D

const LOCKED_TOAST := "Locked in Patch 3A. Coming soon."

@onready var status_label: Label = $CanvasLayer/UIRoot/PanelContainer/VBox/Status
@onready var toast_label: Label = $CanvasLayer/UIRoot/ToastLabel
@onready var enter_cfo_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/EnterCFO
@onready var boardroom_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/Boardroom
@onready var archive_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/Archive
@onready var coffee_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/Coffee
@onready var back_button: Button = $CanvasLayer/UIRoot/PanelContainer/VBox/Buttons/Back

func _ready() -> void:
	_update_status()
	enter_cfo_button.pressed.connect(func() -> void: _goto("res://scenes/CFOOffice.tscn"))
	back_button.pressed.connect(func() -> void: _goto("res://scenes/WorldMap.tscn"))
	boardroom_button.pressed.connect(_show_locked)
	archive_button.pressed.connect(_show_locked)
	coffee_button.pressed.connect(_show_locked)

func _get_loop_snapshot() -> Dictionary:
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
	if snap.has("week"):
		week_text = str(snap.get("week"))
	if snap.has("month"):
		month_text = str(snap.get("month"))
	if status_label:
		status_label.text = "Week %s | Month %s" % [week_text, month_text]

func _show_locked() -> void:
	if toast_label:
		toast_label.text = LOCKED_TOAST
		toast_label.visible = true

func _goto(path: String) -> void:
	get_tree().call_deferred("change_scene_to_file", path)
