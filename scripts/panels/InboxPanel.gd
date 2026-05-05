extends CanvasLayer

const DecisionIntent = preload("res://engine/DecisionIntent.gd")
const BackendClientScript = preload("res://engine/BackendClient.gd")

const CAPABILITY_FLAG := "cap.inbox"
const LOCAL_ACTION_CARDS_PATH := "res://data/actions/flightpath/action_cards_v1.json"
const LOCAL_DEBT_OFFERS_PATH := "res://data/tools/debt_desk/debt_offers_v1.json"
# PATCH 2: local action-card inbox is canonical for v0.1; backend inbox remains future/optional.
const USE_BACKEND_INBOX := false

@onready var api_client: Node = $ApiClient
@onready var subject_label: Label = $PanelContainer/VBox/SubjectLabel
@onready var sender_label: Label = $PanelContainer/VBox/SenderLabel
@onready var body_label: RichTextLabel = $PanelContainer/VBox/BodyLabel
@onready var choice_container: VBoxContainer = get_node_or_null("PanelContainer/VBox/ChoiceContainer") as VBoxContainer
@onready var reply_input: TextEdit = $PanelContainer/VBox/ReplyInput
@onready var send_button: Button = $PanelContainer/VBox/SendButton
@onready var feedback_label: Label = $PanelContainer/VBox/FeedbackLabel

var _backend_client: Node
var _email_id: String = ""
var _inbox_request_in_flight: bool = false
var _advance_enabled: bool = false

func _ready() -> void:
	_ensure_choice_container()
	if USE_BACKEND_INBOX:
		_backend_client = BackendClientScript.new()
		add_child(_backend_client)
		if not _backend_client.inbox_request_finished.is_connected(_on_dynamic_inbox_finished):
			_backend_client.inbox_request_finished.connect(_on_dynamic_inbox_finished)

	if USE_BACKEND_INBOX and api_client:
		api_client.email_generated.connect(_on_email_generated)
		api_client.reply_scored.connect(_on_reply_scored)
	if send_button and not send_button.pressed.is_connected(_on_send_pressed):
		send_button.pressed.connect(_on_send_pressed)

func try_open() -> bool:
	if not _is_unlocked():
		_show_locked_tooltip()
		return false
	open_panel()
	return true

func open_panel() -> void:
	visible = true
	feedback_label.text = ""
	subject_label.text = ""
	sender_label.text = ""
	body_label.text = ""
	reply_input.text = ""
	_email_id = ""
	_advance_enabled = false
	_clear_choice_buttons()
	reply_input.visible = USE_BACKEND_INBOX
	send_button.disabled = true
	send_button.visible = USE_BACKEND_INBOX
	if USE_BACKEND_INBOX:
		feedback_label.text = "Fetching memo..."
		_request_dynamic_inbox()
	else:
		_render_local_inbox()

func _on_email_generated(data: Dictionary) -> void:
	_email_id = str(data.get("email_id", ""))
	subject_label.text = str(data.get("subject", "(no subject)"))
	sender_label.text = str(data.get("sender", ""))
	body_label.text = str(data.get("body", ""))
	feedback_label.text = ""
	send_button.disabled = false

func _on_send_pressed() -> void:
	if not USE_BACKEND_INBOX:
		_on_advance_week_pressed()
		return
	if _email_id == "":
		feedback_label.text = "No email loaded yet."
		return
	var reply_text := reply_input.text.strip_edges()
	if reply_text == "":
		feedback_label.text = "Reply cannot be empty."
		return
	feedback_label.text = "Submitting reply..."
	if api_client:
		api_client.submit_email_reply(_email_id, reply_text)

func _on_reply_scored(result: Dictionary) -> void:
	var french: Dictionary = result.get("french_score", {}) as Dictionary
	var bs: Dictionary = result.get("bullshit_score", {}) as Dictionary
	var feedback := ""
	if french.has("explanation_short"):
		feedback += str(french.get("explanation_short"))
	if bs.has("score_0_100"):
		if feedback != "":
			feedback += " | "
		feedback += "Bullshit score: %s" % str(bs.get("score_0_100"))
	feedback_label.text = feedback
	_apply_effects(result)

func _apply_effects(result: Dictionary) -> void:
	var effects: Dictionary = result.get("effects", {}) as Dictionary
	var cash_delta := float(effects.get("cash_delta", 0.0))
	var audit_delta := float(effects.get("audit_delta", 0.0))
	var reputation_delta := float(effects.get("reputation_delta", 0.0))
	var ops_risk_delta := float(effects.get("ops_risk_delta", 0.0))
	var unlock_flags: Array = effects.get("unlock_flags", []) as Array

	print("Inbox effects:", effects)

	var resolver: Node = get_node_or_null("/root/DecisionResolver")
	if resolver == null:
		push_warning("DecisionResolver missing; effects not applied.")
		return

	var scene_path := ""
	if get_tree() and get_tree().current_scene:
		scene_path = str(get_tree().current_scene.scene_file_path)

	var intent: Dictionary = DecisionIntent.build_intent(
		"academy_email_reply",
		DecisionIntent.VERB_USE,
		"inbox_email",
		scene_path,
		str(get_path())
	)

	var fin_delta := {}
	if cash_delta != 0.0:
		fin_delta["cash_delta"] = cash_delta
	if not fin_delta.is_empty():
		intent["financial_delta"] = fin_delta

	var loop_delta := {}
	if audit_delta != 0.0:
		loop_delta["audit_score_delta"] = audit_delta
	if reputation_delta != 0.0:
		loop_delta["reputation_delta"] = reputation_delta
	if ops_risk_delta != 0.0:
		loop_delta["ops_risk_delta"] = ops_risk_delta
	if unlock_flags.size() > 0:
		var flags_set := {}
		for flag in unlock_flags:
			flags_set[str(flag)] = true
		loop_delta["flags_set"] = flags_set
	if not loop_delta.is_empty():
		intent["loop_delta"] = loop_delta

	var response: Dictionary = resolver.call("resolve_intent", intent) as Dictionary
	if not bool(response.get("ok", false)):
		push_warning("Effects intent rejected: " + str(response.get("errors", [])))

func _is_unlocked() -> bool:
	var loop_system: Node = get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_state_ref"):
		var state = loop_system.call("get_state_ref")
		if state and state.flags.has(CAPABILITY_FLAG):
			return bool(state.flags.get(CAPABILITY_FLAG))
	return false

func _show_locked_tooltip() -> void:
	if get_tree() and get_tree().current_scene:
		var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox")
		if dialogue_box:
			dialogue_box.call("show_text", "Inbox locked. Capability required: %s" % CAPABILITY_FLAG)
			return
	feedback_label.text = "Inbox locked."

func _ensure_choice_container() -> void:
	if choice_container != null:
		return
	var vbox := get_node_or_null("PanelContainer/VBox") as VBoxContainer
	if vbox == null:
		return
	choice_container = VBoxContainer.new()
	choice_container.name = "ChoiceContainer"
	choice_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(choice_container)
	if body_label:
		vbox.move_child(choice_container, body_label.get_index() + 1)

func _render_local_inbox() -> void:
	var mission := _get_queued_month_close_mission()
	if not mission.is_empty():
		_render_month_close_mission(mission)
		return

	var card := _find_card_for_week(_get_current_week())
	if card.is_empty():
		if _has_debt_desk_unlocked():
			if _is_debt_desk_used():
				_render_debt_desk_used()
			else:
				_render_debt_desk_offers()
			return
		_render_no_action_card()
		return
	_render_action_card(card)

func _load_local_action_cards() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_ACTION_CARDS_PATH):
		push_warning("Action cards missing: " + LOCAL_ACTION_CARDS_PATH)
		return {}
	var txt := FileAccess.get_file_as_string(LOCAL_ACTION_CARDS_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	push_warning("Invalid action card JSON: " + LOCAL_ACTION_CARDS_PATH)
	return {}

func _get_current_week() -> int:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("get_current_week"):
		return int(manager.call("get_current_week"))
	var loop_system := get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_state_ref"):
		var state: LoopState = loop_system.call("get_state_ref") as LoopState
		return int(state.week_number) + 1
	return 1

func _find_card_for_week(week_number: int) -> Dictionary:
	var payload := _load_local_action_cards()
	var cards_value: Variant = payload.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		return {}
	var loop_state := _get_loop_state_ref()
	var cards: Array = cards_value as Array
	for card_value in cards:
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = card_value as Dictionary
		if int(card.get("week", 0)) != week_number:
			continue
		var card_id := str(card.get("id", ""))
		if loop_state != null and bool(loop_state.flags.get("card_completed.%s" % card_id, false)):
			return {}
		return card
	return {}

func _render_action_card(card: Dictionary) -> void:
	_clear_choice_buttons()
	_advance_enabled = false
	subject_label.text = str(card.get("title", "Weekly Decision"))
	sender_label.text = str(card.get("sender", "CFO Office"))
	body_label.text = str(card.get("body", ""))
	feedback_label.text = "Choose one response."
	reply_input.visible = false
	send_button.visible = false
	send_button.disabled = true

	var choices_value: Variant = card.get("choices", [])
	if typeof(choices_value) != TYPE_ARRAY:
		feedback_label.text = "This card has no choices."
		return
	var choices: Array = choices_value as Array
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = choice_value as Dictionary
		var button := Button.new()
		button.text = "%s\n%s" % [str(choice.get("label", "Choose")), str(choice.get("description", ""))]
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_choice_pressed.bind(card, choice))
		choice_container.add_child(button)

func _render_no_action_card() -> void:
	_clear_choice_buttons()
	_advance_enabled = true
	subject_label.text = "No Open Decision"
	sender_label.text = "CFO Office"
	body_label.text = "No local action card is scheduled for week %d." % _get_current_week()
	feedback_label.text = "You may advance the week."
	reply_input.visible = false
	send_button.text = "Advance Week"
	send_button.visible = true
	send_button.disabled = false

func _has_debt_desk_unlocked() -> bool:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("is_debt_desk_unlocked"):
		return bool(manager.call("is_debt_desk_unlocked"))
	var loop_state := _get_loop_state_ref()
	return loop_state != null and bool(loop_state.unlocks.get("DEBT_DESK", false))

func _is_debt_desk_used() -> bool:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("is_debt_desk_used"):
		return bool(manager.call("is_debt_desk_used"))
	var loop_state := _get_loop_state_ref()
	return loop_state != null and bool(loop_state.flags.get("tool_used.DEBT_DESK", false))

func _load_debt_offers() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_DEBT_OFFERS_PATH):
		push_warning("Debt offers missing: " + LOCAL_DEBT_OFFERS_PATH)
		return {}
	var txt := FileAccess.get_file_as_string(LOCAL_DEBT_OFFERS_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	push_warning("Invalid debt offers JSON: " + LOCAL_DEBT_OFFERS_PATH)
	return {}

func _render_debt_desk_offers() -> void:
	_clear_choice_buttons()
	_advance_enabled = false
	subject_label.text = "Debt Desk: Financing Options"
	sender_label.text = "Bank Relationship Manager"
	body_label.text = "The Debt Desk is open. Choose a financing action. Cash gets easier; obligations get louder."
	feedback_label.text = "Choose one financing option."
	reply_input.visible = false
	send_button.visible = false
	send_button.disabled = true

	var payload := _load_debt_offers()
	var offers_value: Variant = payload.get("offers", [])
	if typeof(offers_value) != TYPE_ARRAY:
		feedback_label.text = "Debt offers unavailable."
		return
	var offers: Array = offers_value as Array
	for offer_value in offers:
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer: Dictionary = offer_value as Dictionary
		var button := Button.new()
		button.text = "%s\n%s" % [str(offer.get("label", "Choose")), str(offer.get("description", ""))]
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_debt_offer_pressed.bind(offer))
		choice_container.add_child(button)

func _render_debt_desk_used() -> void:
	_clear_choice_buttons()
	_advance_enabled = false
	subject_label.text = "Debt Desk"
	sender_label.text = "Bank Relationship Manager"
	body_label.text = "Debt Desk facility already used in this MVP run. Future patches will add refinancing, repayment, and covenant negotiation."
	feedback_label.text = ""
	reply_input.visible = false
	send_button.visible = false
	send_button.disabled = true

	var button := Button.new()
	button.text = "Close"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		visible = false
	)
	choice_container.add_child(button)

	var advance_button := Button.new()
	advance_button.text = "Advance Week"
	advance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advance_button.pressed.connect(func() -> void:
		var manager := get_node_or_null("/root/GameManager")
		if manager and manager.has_method("advance_week"):
			manager.call("advance_week", false)
			_render_local_inbox()
	)
	choice_container.add_child(advance_button)

func _on_debt_offer_pressed(offer: Dictionary) -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.has_method("submit_debt_desk_choice"):
		feedback_label.text = "GameManager unavailable."
		return
	var offer_id := str(offer.get("id", ""))
	var result: Dictionary = manager.call("submit_debt_desk_choice", offer_id, offer) as Dictionary
	if not bool(result.get("ok", false)):
		var error_texts := PackedStringArray()
		for err in result.get("errors", []):
			error_texts.append(str(err))
		feedback_label.text = "; ".join(error_texts)
		return

	var ui: Dictionary = result.get("ui", {}) as Dictionary
	feedback_label.text = str(ui.get("feedback", offer.get("feedback", "Debt Desk decision applied.")))
	if offer_id != "DECLINE_DEBT":
		_disable_choice_buttons()
		_render_debt_close_button()
	else:
		_render_debt_decline_close_button()

func _render_debt_close_button() -> void:
	var button := Button.new()
	button.text = "Close"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		visible = false
	)
	choice_container.add_child(button)

func _render_debt_decline_close_button() -> void:
	_clear_choice_buttons()
	var button := Button.new()
	button.text = "Close"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		visible = false
	)
	choice_container.add_child(button)

func _on_choice_pressed(card: Dictionary, choice: Dictionary) -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.has_method("submit_action_card_choice"):
		feedback_label.text = "GameManager unavailable."
		return
	var card_id := str(card.get("id", ""))
	var choice_id := str(choice.get("id", ""))
	var result: Dictionary = manager.call("submit_action_card_choice", card_id, choice_id, choice) as Dictionary
	if not bool(result.get("ok", false)):
		var ui: Dictionary = result.get("ui", {}) as Dictionary
		var feedback := str(ui.get("feedback", ""))
		if feedback.strip_edges() != "":
			feedback_label.text = feedback
			return
		var error_texts := PackedStringArray()
		for err in result.get("errors", []):
			error_texts.append(str(err))
		feedback_label.text = "; ".join(error_texts)
		return

	var ui: Dictionary = result.get("ui", {}) as Dictionary
	var feedback := str(ui.get("feedback", choice.get("feedback", "Decision applied.")))
	feedback_label.text = feedback
	_disable_choice_buttons()
	_advance_enabled = true
	send_button.text = "Advance Week"
	send_button.visible = true
	send_button.disabled = false

func _on_advance_week_pressed() -> void:
	if not _advance_enabled:
		feedback_label.text = "Choose a response before advancing the week."
		return
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.has_method("advance_week"):
		feedback_label.text = "GameManager unavailable."
		return
	manager.call("advance_week", false)
	_show_dialogue_feedback()
	_render_local_inbox()

func _get_queued_month_close_mission() -> Dictionary:
	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager == null or not mission_manager.has_method("get_inbox"):
		return {}
	var inbox: Array = mission_manager.call("get_inbox") as Array
	for item_value in inbox:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value as Dictionary
		if str(item.get("type", "")) == "month_close" and str(item.get("status", "queued")) == "queued":
			return item
	return {}

func _render_month_close_mission(mission: Dictionary) -> void:
	_clear_choice_buttons()
	_advance_enabled = false
	subject_label.text = str(mission.get("title", "Month Close"))
	sender_label.text = "Board Secretary"
	body_label.text = "Month close is ready. The board wants answers."
	feedback_label.text = ""
	reply_input.visible = false
	send_button.visible = false
	send_button.disabled = true

	var button := Button.new()
	button.text = "Enter Boardroom"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mission_id := str(mission.get("mission_id", ""))
	button.pressed.connect(func() -> void:
		var mission_manager := get_node_or_null("/root/MissionManager")
		if mission_manager and mission_manager.has_method("start_mission"):
			mission_manager.call("start_mission", mission_id)
			visible = false
	)
	choice_container.add_child(button)

func _get_loop_state_ref() -> LoopState:
	var manager := get_node_or_null("/root/GameManager")
	if manager and manager.has_method("get_loop_state_ref"):
		return manager.call("get_loop_state_ref") as LoopState
	var loop_system := get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_state_ref"):
		return loop_system.call("get_state_ref") as LoopState
	return null

func _clear_choice_buttons() -> void:
	if choice_container == null:
		return
	for child in choice_container.get_children():
		choice_container.remove_child(child)
		child.queue_free()

func _disable_choice_buttons() -> void:
	if choice_container == null:
		return
	for child in choice_container.get_children():
		if child is Button:
			(child as Button).disabled = true

func _show_dialogue_feedback() -> void:
	var loop_state := _get_loop_state_ref()
	if loop_state == null:
		return
	var feedback := str(loop_state.memory.get("last_action_feedback", ""))
	if feedback == "":
		return
	if get_tree() and get_tree().current_scene:
		var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox")
		if dialogue_box:
			dialogue_box.call("show_text", feedback)


func _request_dynamic_inbox() -> void:
	if _backend_client == null:
		_apply_fallback_memo("backend_client_missing")
		return
	if _inbox_request_in_flight:
		feedback_label.text = "Memo request already in progress..."
		return

	var context := _build_request_context()
	var payload := _build_inbox_payload(context)
	_inbox_request_in_flight = true
	_backend_client.fetch_inbox(context, payload)


func _build_request_context() -> Dictionary:
	var loop_snapshot: Dictionary = {}
	var loop_system: Node = get_node_or_null("/root/LoopSystem")
	if loop_system and loop_system.has_method("get_snapshot"):
		loop_snapshot = loop_system.call("get_snapshot") as Dictionary

	var month := int(loop_snapshot.get("month_number", 1))
	var week := int(loop_snapshot.get("week_number", 1))
	var audit_score := float(loop_snapshot.get("audit_score", 0.0))

	var scenario_id := "unknown_scenario"
	var scenario_version := "1.0.0"
	var domain_module := "redline"
	var parent_node := get_parent()
	if parent_node != null:
		var scenario_variant: Variant = parent_node.get("current_scenario")
		if typeof(scenario_variant) == TYPE_DICTIONARY:
			var scenario := scenario_variant as Dictionary
			scenario_id = str(scenario.get("id", scenario_id))
			scenario_version = str(scenario.get("version", scenario_version))
			domain_module = str(scenario.get("domain_module", domain_module))

	return {
		"loop_snapshot": loop_snapshot,
		"audit_score": audit_score,
		"month": month,
		"week": week,
		"client": {
			"platform": OS.get_name().to_lower(),
			"build_version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
			"environment": "local"
		},
		"scenario": {
			"scenario_id": scenario_id,
			"scenario_version": scenario_version,
			"domain_module": domain_module
		},
		"run_context": {
			# TODO: replace placeholders with canonical runtime ids when exposed by engine services.
			"run_id": "local_run",
			"turn_index": max(week, 0),
			"week": max(week, 1),
			"month": max(month, 1),
			"quarter": int(((max(month, 1) - 1) / 3) + 1),
			"year": 1,
			"seed": 0
		}
	}


func _build_inbox_payload(context: Dictionary) -> Dictionary:
	var facts := _extract_inbox_facts(context)
	return {
		"message_type": "executive_email",
		"sender_role": "cfo",
		"recipient_role": "player",
		"objective": "highlight liquidity and audit posture",
		"facts": facts,
		"constraints": {
			"max_words": 120,
			"urgency": "medium"
		}
	}


func _extract_inbox_facts(context: Dictionary) -> Dictionary:
	var facts := {
		"month": int(context.get("month", 1)),
		"audit_score": float(context.get("audit_score", 0.0))
	}

	var resolver: Node = get_node_or_null("/root/DecisionResolver")
	if resolver and resolver.has_method("get_financial_state_ref"):
		var state: Object = resolver.call("get_financial_state_ref")
		if state and state.has_method("get_financial_summary"):
			var summary := state.call("get_financial_summary") as Dictionary
			var balance := summary.get("balance_sheet", {}) as Dictionary
			facts["cash"] = float(balance.get("cash", 0.0))

	return facts


func _on_dynamic_inbox_finished(result: Dictionary) -> void:
	_inbox_request_in_flight = false

	if not bool(result.get("ok", false)):
		_apply_fallback_memo(str(result.get("error", "unknown")))
		return

	var message_variant: Variant = result.get("message", {})
	if typeof(message_variant) != TYPE_DICTIONARY:
		_apply_fallback_memo("message_not_object")
		return

	var message := message_variant as Dictionary
	subject_label.text = str(message.get("subject", "Weekly Finance Check-In"))
	sender_label.text = str(message.get("from_label", "CFO Office"))
	body_label.text = str(message.get("body", "No message body provided."))
	feedback_label.text = "Memo ready."


func _apply_fallback_memo(reason: String) -> void:
	push_warning("Dynamic inbox unavailable: %s" % reason)
	subject_label.text = "Weekly Finance Check-In"
	sender_label.text = "CFO Office"
	body_label.text = (
		"Dynamic inbox is unavailable right now. "
		+ "Review cash position, expense discipline, and audit readiness before advancing."
	)
	feedback_label.text = "Using fallback memo."
