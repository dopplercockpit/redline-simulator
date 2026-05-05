extends CanvasLayer

const CONTRACT_REVIEWS_PATH := "res://data/tools/contract_review/contract_reviews_v1.json"
const DEFAULT_REVIEW_ID := "BUDGETAIR_INCENTIVE_REVIEW"

@onready var body: RichTextLabel = $PanelContainer/ScrollContainer/VBoxContainer/Body
@onready var close_button: Button = $PanelContainer/ScrollContainer/VBoxContainer/Close

var _dynamic_buttons: Array[Button] = []

func load_contract_template(path: String, vars: Dictionary) -> void:
	_clear_dynamic_buttons()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		body.bbcode_text = "[b]Missing contract template[/b]\n" + path
		return

	var text := _render_template_text(f.get_as_text(), vars)
	body.bbcode_text = "[code]" + text + "[/code]"

func _ready() -> void:
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func open_contract_review_tool(review_id: String = DEFAULT_REVIEW_ID) -> void:
	visible = true
	if not _is_contract_review_unlocked():
		_render_contract_review_locked()
		return

	var review := _find_review(review_id)
	if review.is_empty():
		_clear_dynamic_buttons()
		body.bbcode_text = "[b]Contract review not found[/b]\n" + review_id
		return

	if _is_contract_review_completed(review_id):
		_render_contract_review_completed(review)
		return

	_render_contract_review(review)

func _load_contract_reviews() -> Dictionary:
	if not FileAccess.file_exists(CONTRACT_REVIEWS_PATH):
		push_warning("Contract reviews file not found: " + CONTRACT_REVIEWS_PATH)
		return {}
	var text := FileAccess.get_file_as_string(CONTRACT_REVIEWS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	push_warning("Invalid contract reviews JSON: " + CONTRACT_REVIEWS_PATH)
	return {}

func _find_review(review_id: String) -> Dictionary:
	var data := _load_contract_reviews()
	var reviews_value: Variant = data.get("reviews", [])
	if typeof(reviews_value) != TYPE_ARRAY:
		return {}
	var reviews: Array = reviews_value as Array
	for review_value in reviews:
		if typeof(review_value) != TYPE_DICTIONARY:
			continue
		var review: Dictionary = review_value as Dictionary
		if str(review.get("id", "")) == review_id:
			return review.duplicate(true)
	return {}

func _render_contract_review(review: Dictionary) -> void:
	_clear_dynamic_buttons()
	var title := str(review.get("title", "Contract Review"))
	var sender := str(review.get("sender", "General Counsel"))
	var review_body := str(review.get("body", "Review the draft contract."))
	var template_path := str(review.get("contract_template", ""))
	var vars: Dictionary = review.get("vars", {}) as Dictionary
	var contract_text := _load_and_render_template(template_path, vars)

	body.bbcode_text = (
		"[b]%s[/b]\n" % _escape_bbcode(title)
		+ "From: %s\n\n" % _escape_bbcode(sender)
		+ "%s\n\n" % _escape_bbcode(review_body)
		+ "[b]Draft Agreement[/b]\n"
		+ "[code]%s[/code]\n\n" % _escape_bbcode(contract_text)
		+ "[b]Choose handling approach:[/b]"
	)

	var choices_value: Variant = review.get("choices", [])
	if typeof(choices_value) != TYPE_ARRAY:
		return
	var choices: Array = choices_value as Array
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = (choice_value as Dictionary).duplicate(true)
		var button := Button.new()
		button.text = "%s - %s" % [
			str(choice.get("label", choice.get("id", "Choice"))),
			str(choice.get("description", ""))
		]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_contract_choice_pressed.bind(review, choice))
		_add_dynamic_button(button)

func _render_contract_review_locked() -> void:
	_clear_dynamic_buttons()
	body.text = "Contract Review is locked. Complete the route incentive boardroom objective first."
	_render_close_button_if_needed()

func _render_contract_review_completed(review: Dictionary) -> void:
	_clear_dynamic_buttons()
	var review_id := str(review.get("id", DEFAULT_REVIEW_ID))
	var stored := _get_stored_contract_review(review_id)
	var lines: Array[String] = []
	lines.append("This contract review has already been completed.")
	if not stored.is_empty():
		lines.append("")
		lines.append("Status: %s" % str(stored.get("status", "unknown")))
		lines.append("Risk Rating: %s" % str(stored.get("risk_rating", "unknown")))
		lines.append("Clawback: %s" % str(stored.get("clawback_strength", "unknown")))
		lines.append("Minimum Service Commitment: %s" % ("Yes" if bool(stored.get("minimum_service_commitment", false)) else "No"))
		lines.append("Feedback: %s" % str(stored.get("feedback", "")))
	body.text = "\n".join(PackedStringArray(lines))
	_render_close_button_if_needed()

func _on_contract_choice_pressed(review: Dictionary, choice: Dictionary) -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.has_method("submit_contract_review_choice"):
		body.text = "Contract Review unavailable. GameManager is missing."
		return

	var review_id := str(review.get("id", ""))
	var choice_id := str(choice.get("id", ""))
	var result: Dictionary = manager.call("submit_contract_review_choice", review_id, choice_id, choice) as Dictionary
	var feedback := str((result.get("ui", {}) as Dictionary).get("feedback", ""))
	if not bool(result.get("ok", false)):
		if feedback == "":
			feedback = "Contract review failed: %s" % str(result.get("errors", []))
		body.text = feedback
		return

	for button in _dynamic_buttons:
		if is_instance_valid(button):
			button.disabled = true
	body.text = feedback

func _clear_dynamic_buttons() -> void:
	for button in _dynamic_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_dynamic_buttons.clear()
	_render_close_button_if_needed()

func _render_close_button_if_needed() -> void:
	if close_button:
		close_button.visible = true

func _add_dynamic_button(button: Button) -> void:
	var parent := close_button.get_parent()
	parent.add_child(button)
	parent.move_child(button, close_button.get_index())
	_dynamic_buttons.append(button)

func _is_contract_review_unlocked() -> bool:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("is_contract_review_unlocked"):
		return bool(manager.call("is_contract_review_unlocked"))
	return false

func _is_contract_review_completed(review_id: String) -> bool:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("is_contract_review_completed"):
		return bool(manager.call("is_contract_review_completed", review_id))
	return false

func _get_stored_contract_review(review_id: String) -> Dictionary:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.has_method("get_loop_snapshot"):
		return {}
	var loop_snapshot: Dictionary = manager.call("get_loop_snapshot") as Dictionary
	var memory: Dictionary = loop_snapshot.get("memory", {}) as Dictionary
	var reviews_value: Variant = memory.get("contract_reviews", {})
	if typeof(reviews_value) != TYPE_DICTIONARY:
		return {}
	var reviews: Dictionary = reviews_value as Dictionary
	var stored_value: Variant = reviews.get(review_id, {})
	if typeof(stored_value) == TYPE_DICTIONARY:
		return stored_value as Dictionary
	return {}

func _load_and_render_template(path: String, vars: Dictionary) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "Missing contract template: " + path
	return _render_template_text(f.get_as_text(), vars)

func _render_template_text(text: String, vars: Dictionary) -> String:
	for key in vars.keys():
		var placeholder := "[" + str(key) + "]"
		text = text.replace(placeholder, str(vars.get(key, "[MISSING]")))

	var missing_re := RegEx.new()
	missing_re.compile("\\[[A-Z0-9_]+\\]")
	return missing_re.sub(text, "[MISSING]", true)

func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")

func _on_close_pressed() -> void:
		visible = false
