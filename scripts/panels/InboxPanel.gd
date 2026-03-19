extends CanvasLayer

const DecisionIntent = preload("res://engine/DecisionIntent.gd")

const CAPABILITY_FLAG := "cap.inbox"

@onready var api_client: Node = $ApiClient
@onready var subject_label: Label = $PanelContainer/VBox/SubjectLabel
@onready var sender_label: Label = $PanelContainer/VBox/SenderLabel
@onready var body_label: RichTextLabel = $PanelContainer/VBox/BodyLabel
@onready var reply_input: TextEdit = $PanelContainer/VBox/ReplyInput
@onready var send_button: Button = $PanelContainer/VBox/SendButton
@onready var feedback_label: Label = $PanelContainer/VBox/FeedbackLabel

var _backend_client: BackendClient
var _email_id: String = ""
var _inbox_request_in_flight: bool = false

func _ready() -> void:
	_backend_client = BackendClient.new()
	add_child(_backend_client)
	if not _backend_client.inbox_request_finished.is_connected(_on_dynamic_inbox_finished):
		_backend_client.inbox_request_finished.connect(_on_dynamic_inbox_finished)

	if api_client:
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
	feedback_label.text = "Fetching memo..."
	subject_label.text = ""
	sender_label.text = ""
	body_label.text = ""
	reply_input.text = ""
	_email_id = ""
	send_button.disabled = true
	_request_dynamic_inbox()

func _on_email_generated(data: Dictionary) -> void:
	_email_id = str(data.get("email_id", ""))
	subject_label.text = str(data.get("subject", "(no subject)"))
	sender_label.text = str(data.get("sender", ""))
	body_label.text = str(data.get("body", ""))
	feedback_label.text = ""
	send_button.disabled = false

func _on_send_pressed() -> void:
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
		"Review cash position, expense discipline, and audit readiness before advancing."
	)
	feedback_label.text = "Using fallback memo."
