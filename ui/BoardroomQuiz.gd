# res://ui/BoardroomQuiz.gd
extends CanvasLayer

@onready var title_label: Label = $PanelContainer/VBox/Title
@onready var progress_label: Label = $PanelContainer/VBox/Progress
@onready var prompt_label: RichTextLabel = $PanelContainer/VBox/Prompt
@onready var answers_box: VBoxContainer = $PanelContainer/VBox/Answers
@onready var result_label: Label = $PanelContainer/VBox/Result
@onready var finish_button: Button = $PanelContainer/VBox/Finish

var _mission_id: String = ""
var _mission_def: Dictionary = {}
var _loop_snapshot: Dictionary = {}
var _questions: Array = []
var _current_index: int = 0
var _correct: int = 0
var _wrong: int = 0
var _points_per_correct: int = 0
var _completed: bool = false
var _answer_buttons: Array = []

func _ready() -> void:
	_cache_answer_buttons()
	finish_button.pressed.connect(_on_finish_pressed)
	result_label.visible = false
	finish_button.visible = false

func setup(mission_id: String, mission_def: Dictionary, loop_snapshot: Dictionary = {}) -> void:
	_mission_id = mission_id
	_mission_def = mission_def
	_loop_snapshot = loop_snapshot
	var q_var: Variant = mission_def.get("questions", [])
	_questions = q_var if typeof(q_var) == TYPE_ARRAY else []
	var scoring: Dictionary = mission_def.get("scoring", {}) as Dictionary
	_points_per_correct = int(scoring.get("points_per_correct", 0))
	_current_index = 0
	_correct = 0
	_wrong = 0
	_completed = false
	if title_label:
		title_label.text = str(mission_def.get("title", "Boardroom Quiz"))
	_show_question()

func _cache_answer_buttons() -> void:
	_answer_buttons.clear()
	for child in answers_box.get_children():
		if child is Button:
			var btn: Button = child
			var idx := _answer_buttons.size()
			btn.pressed.connect(func() -> void: _on_answer_pressed(idx))
			_answer_buttons.append(btn)

func _show_question() -> void:
	if _current_index >= _questions.size():
		_show_results()
		return

	var q: Dictionary = _questions[_current_index] as Dictionary
	var prompt := str(q.get("prompt", ""))
	var choices_var: Variant = q.get("choices", [])
	var choices: Array = choices_var if typeof(choices_var) == TYPE_ARRAY else []

	if progress_label:
		progress_label.text = "Question %d/%d" % [_current_index + 1, _questions.size()]
	if prompt_label:
		prompt_label.text = prompt
	if result_label:
		result_label.visible = false
	if finish_button:
		finish_button.visible = false

	for i in range(_answer_buttons.size()):
		var btn: Button = _answer_buttons[i]
		if i < choices.size():
			btn.text = str(choices[i])
			btn.visible = true
			btn.disabled = false
		else:
			btn.visible = false

func _on_answer_pressed(choice_index: int) -> void:
	if _completed:
		return
	if _current_index >= _questions.size():
		return

	var q: Dictionary = _questions[_current_index] as Dictionary
	var correct_index: int = int(q.get("correct_index", -1))
	if choice_index == correct_index:
		_correct += 1
	else:
		_wrong += 1

	_current_index += 1
	_show_question()

func _show_results() -> void:
	_completed = true
	var score: int = _correct * _points_per_correct
	if progress_label:
		progress_label.text = "Complete"
	if result_label:
		result_label.text = "Score: %d | Correct: %d | Wrong: %d" % [score, _correct, _wrong]
		result_label.visible = true
	if finish_button:
		finish_button.visible = true
	for btn in _answer_buttons:
		btn.visible = false

	var manager := get_node_or_null("/root/MissionManager")
	if manager:
		manager.call("complete_mission", _mission_id, {
			"mission_id": _mission_id,
			"score": score,
			"correct": _correct,
			"wrong": _wrong
		})

func _on_finish_pressed() -> void:
	queue_free()
