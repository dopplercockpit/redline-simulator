# res://engine/DecisionResolver.gd
extends Node

signal decision_applied(tag: String, impacts: Dictionary)
signal week_advanced(week_number: int, month_number: int, is_month_end: bool)
signal month_end_ready(month_number: int, report: Dictionary)

const LEGACY_WEEKLY_OPEX_USD := 5000.0
const DecisionIntent = preload("res://engine/DecisionIntent.gd")

var _loop_system: Node = null
var _financial_state: GameStateData = preload("res://engine/state.gd").new()
var _finance := preload("res://engine/finance.gd").new()
var _ledger := preload("res://engine/ledger.gd").new()
var _last_month_report: Dictionary = {}

func _ready() -> void:
	_loop_system = get_node_or_null("/root/LoopSystem")
	if _loop_system == null:
		push_warning("LoopSystem autoload missing; loop state will not advance.")

func load_scenario(cfg: Dictionary) -> void:
	_financial_state.reset()
	_financial_state.load_config(cfg.get("initial_state", {}))
	# PATCH 1: LEDGER
	# Capture scenario meta (e.g., finance_mode) while preserving any meta set during initial_state load (e.g., coa_ref).
	var _pre_meta: Dictionary = _financial_state.meta.duplicate(true)
	var scenario_meta: Dictionary = {}
	if cfg.has("meta") and typeof(cfg["meta"]) == TYPE_DICTIONARY:
		scenario_meta = (cfg["meta"] as Dictionary).duplicate(true)
	_financial_state.meta = scenario_meta
	for key in _pre_meta.keys():
		if not _financial_state.meta.has(key):
			_financial_state.meta[key] = _pre_meta[key]
	if _loop_system:
		_loop_system.call("reset")

func seed_financial_state(cfg: Dictionary, reset: bool = true) -> void:
	if reset:
		_financial_state.reset()

	var source: Dictionary = cfg
	if cfg.has("financial_statements") and typeof(cfg["financial_statements"]) == TYPE_DICTIONARY:
		source = cfg["financial_statements"] as Dictionary

	var is_structured := source.has("income_statement") or source.has("balance_sheet") or source.has("cash_flow")
	if is_structured:
		# Temporary adapter for statement-style JSON inputs.
		var income_statement: Dictionary = source.get("income_statement", {}) as Dictionary
		var balance_sheet: Dictionary = source.get("balance_sheet", {}) as Dictionary
		var cash_flow: Dictionary = source.get("cash_flow", {}) as Dictionary
		_financial_state.load_from_statements(income_statement, balance_sheet, cash_flow)
		return

	_financial_state.load_config(source)

func get_financial_state_ref() -> GameStateData:
	# Exposed read-only by convention.
	return _financial_state

func get_financial_snapshot() -> Dictionary:
	return _financial_state.get_financial_summary()

func get_loop_snapshot() -> Dictionary:
	if _loop_system:
		return _loop_system.call("get_snapshot") as Dictionary
	return {}

func get_last_month_report() -> Dictionary:
	return _last_month_report

func advance_week(use_legacy_burn: bool = false) -> Dictionary:
	var impacts: Dictionary = {}
	if use_legacy_burn:
		impacts["financial"] = _apply_weekly_burn(LEGACY_WEEKLY_OPEX_USD)
	else:
		impacts["financial"] = _apply_weekly_finance()

	var turn_info: Dictionary = _advance_loop_time()
	var month_report: Dictionary = {}
	emit_signal("week_advanced", turn_info["week_number"], turn_info["month_number"], turn_info["is_month_end"])
	if turn_info["is_month_end"]:
		month_report = _last_month_report
		emit_signal("month_end_ready", turn_info["closed_month"], month_report)

	return {
		"turn": turn_info,
		"impacts": impacts,
		"month_report": month_report
	}

func resolve_intent(intent: Dictionary) -> Dictionary:
	var validation: Dictionary = DecisionIntent.validate_intent(intent)
	var errors: Array[String] = validation.get("errors", []) as Array[String]
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": errors,
			"ui": {}
		}

	if intent.has("action_card_choice") and typeof(intent["action_card_choice"]) == TYPE_DICTIONARY:
		var action_card_choice: Dictionary = intent["action_card_choice"] as Dictionary
		return _apply_action_card_choice(
			str(action_card_choice.get("card_id", "")),
			str(action_card_choice.get("choice_id", "")),
			action_card_choice.get("choice", {}) as Dictionary
		)

	if intent.has("debt_desk_choice") and typeof(intent["debt_desk_choice"]) == TYPE_DICTIONARY:
		var debt_desk_choice: Dictionary = intent["debt_desk_choice"] as Dictionary
		return _apply_debt_desk_choice(
			str(debt_desk_choice.get("offer_id", "")),
			debt_desk_choice.get("offer", {}) as Dictionary
		)

	if intent.has("contract_review_choice") and typeof(intent["contract_review_choice"]) == TYPE_DICTIONARY:
		var contract_review_choice: Dictionary = intent["contract_review_choice"] as Dictionary
		return _apply_contract_review_choice(
			str(contract_review_choice.get("review_id", "")),
			str(contract_review_choice.get("choice_id", "")),
			contract_review_choice.get("choice", {}) as Dictionary
		)

	if intent.has("audit_room_choice") and typeof(intent["audit_room_choice"]) == TYPE_DICTIONARY:
		var audit_room_choice: Dictionary = intent["audit_room_choice"] as Dictionary
		return _apply_audit_room_choice(
			str(audit_room_choice.get("remediation_id", "")),
			audit_room_choice.get("choice", {}) as Dictionary
		)

	var impacts: Dictionary = {}
	var verb := str(intent.get("verb", "intent"))
	var target := str(intent.get("target", "target"))
	var tag := verb + "." + target

	if intent.has("financial_delta"):
		impacts["financial"] = _apply_financial_delta(intent["financial_delta"])

	# PATCH 1: LEDGER
	# Manual test intent example (submit_intent/resolve_intent):
	# "ledger_tx": [{
	#   "memo": "Manual cash funding",
	#   "journal": [
	#     {"gl":"1000","dc":"D","amount":100.0},
	#     {"gl":"3000","dc":"C","amount":100.0}
	#   ]
	# }]
	if intent.has("ledger_tx"):
		var txs = intent["ledger_tx"]
		if typeof(txs) == TYPE_ARRAY:
			var posted := 0
			var errs: Array[String] = []
			for tx in txs:
				if typeof(tx) != TYPE_DICTIONARY:
					continue
				var tx_dict: Dictionary = tx as Dictionary
				var result: Dictionary = _ledger.post_transaction(_financial_state.ledger, tx_dict)
				if bool(result.get("ok", false)):
					posted += 1
				else:
					var e = result.get("errors", [])
					if typeof(e) == TYPE_ARRAY:
						for msg in e:
							errs.append(str(msg))
			impacts["ledger"] = {"posted": posted, "errors": errs}
		else:
			impacts["ledger"] = {"posted": 0, "errors": ["ledger_tx must be an Array"]}

	if intent.has("loop_delta"):
		impacts["loop"] = _apply_loop_delta(intent["loop_delta"])

	emit_signal("decision_applied", tag, impacts)
	return {
		"ok": true,
		"impacts": impacts,
		"events": [],
		"errors": [],
		"ui": {}
	}

func _apply_debt_desk_choice(offer_id: String, offer: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if offer_id.strip_edges() == "":
		errors.append("Debt Desk offer missing offer_id.")
	if _loop_system == null:
		errors.append("LoopSystem unavailable")
	if not errors.is_empty():
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": errors,
			"ui": {}
		}

	var loop_state: LoopState = _loop_system.call("get_state_ref") as LoopState
	if not bool(loop_state.unlocks.get("DEBT_DESK", false)):
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": ["Debt Desk is locked."],
			"ui": {"feedback": "Debt Desk is locked."}
		}

	if bool(loop_state.flags.get("tool_used.DEBT_DESK", false)):
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": ["Debt Desk already used in this MVP run."],
			"ui": {"feedback": "Debt Desk already used in this MVP run."}
		}

	var ledger_posted := 0
	var ledger_errors: Array[String] = []
	var ledger_value: Variant = offer.get("ledger_tx", [])
	if typeof(ledger_value) == TYPE_ARRAY:
		var txs: Array = ledger_value as Array
		for i in range(txs.size()):
			var tx_value: Variant = txs[i]
			if typeof(tx_value) != TYPE_DICTIONARY:
				ledger_errors.append("ledger_tx entry must be a Dictionary")
				continue
			var tx: Dictionary = (tx_value as Dictionary).duplicate(true)
			tx["tx_id"] = "DEBT_DESK_%s_%s" % [offer_id, str(i).pad_zeros(3)]
			tx["week"] = get_current_decision_week()
			tx["source"] = "debt_desk"
			tx["offer_id"] = offer_id
			var result: Dictionary = _ledger.post_transaction(_financial_state.ledger, tx)
			if bool(result.get("ok", false)):
				ledger_posted += 1
			else:
				for msg in result.get("errors", []):
					ledger_errors.append(str(msg))
	elif ledger_value != null:
		ledger_errors.append("ledger_tx must be an Array")

	var debt_added := false
	if ledger_errors.is_empty() and offer.has("debt_stack_add") and typeof(offer["debt_stack_add"]) == TYPE_DICTIONARY:
		var debt_item: Dictionary = (offer["debt_stack_add"] as Dictionary).duplicate(true)
		if float(debt_item.get("principal", 0.0)) > 0.0:
			_financial_state.debt_stack.append(debt_item)
			_financial_state.finance["debt_stack"] = _financial_state.debt_stack.duplicate(true)
			debt_added = true

	var loop_impact: Dictionary = {}
	if ledger_errors.is_empty() and offer.has("loop_delta") and typeof(offer["loop_delta"]) == TYPE_DICTIONARY:
		loop_impact = _apply_loop_delta(offer["loop_delta"] as Dictionary)

	var statements := _finance.generate_statements_from_ledger(_financial_state)
	_financial_state.meta["financial_statements"] = statements
	var balance_sheet: Dictionary = statements.get("balance_sheet", {}) as Dictionary
	_financial_state.cash = float(balance_sheet.get("cash", _financial_state.cash))

	var feedback := str(offer.get("feedback", "Debt Desk decision applied."))
	loop_state.memory["last_debt_desk_feedback"] = feedback
	if offer_id == "DECLINE_DEBT":
		# Declining is a preview/discipline choice. It does not consume the only Patch 4 draw.
		loop_state.flags["tool_seen.DEBT_DESK"] = true
	elif ledger_errors.is_empty():
		loop_state.flags["tool_used.DEBT_DESK"] = true

	_loop_system.call("notify_updated")

	var debt_impact := {
		"offer_id": offer_id,
		"ledger_posted": ledger_posted,
		"debt_added": debt_added,
		"feedback": feedback,
		"errors": ledger_errors
	}
	var impacts := {
		"debt_desk": debt_impact,
		"loop": loop_impact
	}
	emit_signal("decision_applied", "debt_desk.%s" % offer_id, impacts)
	return {
		"ok": ledger_errors.is_empty(),
		"impacts": impacts,
		"events": [],
		"errors": ledger_errors,
		"ui": {
			"feedback": feedback
		}
	}

func _apply_contract_review_choice(review_id: String, choice_id: String, choice: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if review_id.strip_edges() == "":
		errors.append("Contract review missing review_id.")
	if choice_id.strip_edges() == "":
		errors.append("Contract review missing choice_id.")
	if _loop_system == null:
		errors.append("LoopSystem unavailable")
	if not errors.is_empty():
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": errors,
			"ui": {}
		}

	var loop_state: LoopState = _loop_system.call("get_state_ref") as LoopState
	if not bool(loop_state.unlocks.get("CONTRACT_REVIEW", false)):
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": ["Contract Review is locked."],
			"ui": {"feedback": "Contract Review is locked."}
		}

	var completed_flag := "contract_review_completed.%s" % review_id
	if bool(loop_state.flags.get(completed_flag, false)):
		var duplicate_error := "Contract review already completed: %s" % review_id
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": [duplicate_error],
			"ui": {"feedback": duplicate_error}
		}

	var ledger_posted := 0
	var ledger_errors: Array[String] = []
	var ledger_value: Variant = choice.get("ledger_tx", [])
	if typeof(ledger_value) == TYPE_ARRAY:
		var txs: Array = ledger_value as Array
		for i in range(txs.size()):
			var tx_value: Variant = txs[i]
			if typeof(tx_value) != TYPE_DICTIONARY:
				ledger_errors.append("ledger_tx entry must be a Dictionary")
				continue
			var tx: Dictionary = (tx_value as Dictionary).duplicate(true)
			tx["tx_id"] = "CONTRACT_%s_%s_%s" % [review_id, choice_id, str(i).pad_zeros(3)]
			tx["week"] = get_current_decision_week()
			tx["source"] = "contract_review"
			tx["review_id"] = review_id
			tx["choice_id"] = choice_id
			var result: Dictionary = _ledger.post_transaction(_financial_state.ledger, tx)
			if bool(result.get("ok", false)):
				ledger_posted += 1
			else:
				for msg in result.get("errors", []):
					ledger_errors.append(str(msg))
	elif ledger_value != null:
		ledger_errors.append("ledger_tx must be an Array")

	var loop_impact: Dictionary = {}
	var contract_result: Dictionary = {}
	var feedback := str(choice.get("feedback", "Contract review applied."))
	if ledger_errors.is_empty():
		if choice.has("loop_delta") and typeof(choice["loop_delta"]) == TYPE_DICTIONARY:
			loop_impact = _apply_loop_delta(choice["loop_delta"] as Dictionary)

		var contract_delta: Dictionary = {}
		if choice.has("contract_delta") and typeof(choice["contract_delta"]) == TYPE_DICTIONARY:
			contract_delta = (choice["contract_delta"] as Dictionary).duplicate(true)
		contract_result = _upsert_contract_review_state(review_id, choice_id, contract_delta)

		var review_memory_value: Variant = loop_state.memory.get("contract_reviews", {})
		var review_memory: Dictionary = {}
		if typeof(review_memory_value) == TYPE_DICTIONARY:
			review_memory = review_memory_value as Dictionary
		review_memory[review_id] = contract_result.duplicate(true)
		review_memory[review_id]["feedback"] = feedback
		loop_state.memory["contract_reviews"] = review_memory
		loop_state.memory["last_contract_review_feedback"] = feedback
		loop_state.flags[completed_flag] = true

	var statements := _finance.generate_statements_from_ledger(_financial_state)
	_financial_state.meta["financial_statements"] = statements
	var balance_sheet: Dictionary = statements.get("balance_sheet", {}) as Dictionary
	_financial_state.cash = float(balance_sheet.get("cash", _financial_state.cash))

	_loop_system.call("notify_updated")

	var contract_impact := {
		"review_id": review_id,
		"choice_id": choice_id,
		"ledger_posted": ledger_posted,
		"contract_status": str(contract_result.get("status", "")),
		"risk_rating": str(contract_result.get("risk_rating", "")),
		"feedback": feedback,
		"errors": ledger_errors
	}
	var impacts := {
		"contract_review": contract_impact,
		"loop": loop_impact
	}
	emit_signal("decision_applied", "contract_review.%s" % review_id, impacts)
	return {
		"ok": ledger_errors.is_empty(),
		"impacts": impacts,
		"events": [],
		"errors": ledger_errors,
		"ui": {
			"feedback": feedback
		}
	}

func _apply_audit_room_choice(remediation_id: String, choice: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	if remediation_id.strip_edges() == "":
		errors.append("Audit Room remediation missing remediation_id.")
	if _loop_system == null:
		errors.append("LoopSystem unavailable")
	if not errors.is_empty():
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": errors,
			"ui": {}
		}

	var loop_state: LoopState = _loop_system.call("get_state_ref") as LoopState
	if not bool(loop_state.unlocks.get("AUDIT_ROOM", false)):
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": ["Audit Room is locked."],
			"ui": {"feedback": "Audit Room is locked."}
		}

	if bool(loop_state.flags.get("tool_used.AUDIT_ROOM", false)):
		var duplicate_error := "Audit Room remediation already used in this MVP run."
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": [duplicate_error],
			"ui": {"feedback": duplicate_error}
		}

	var ledger_posted := 0
	var ledger_errors: Array[String] = []
	var ledger_value: Variant = choice.get("ledger_tx", [])
	if typeof(ledger_value) == TYPE_ARRAY:
		var txs: Array = ledger_value as Array
		for i in range(txs.size()):
			var tx_value: Variant = txs[i]
			if typeof(tx_value) != TYPE_DICTIONARY:
				ledger_errors.append("ledger_tx entry must be a Dictionary")
				continue
			var tx: Dictionary = (tx_value as Dictionary).duplicate(true)
			tx["tx_id"] = "AUDIT_ROOM_%s_%s" % [remediation_id, str(i).pad_zeros(3)]
			tx["week"] = get_current_decision_week()
			tx["source"] = "audit_room"
			tx["remediation_id"] = remediation_id
			var result: Dictionary = _ledger.post_transaction(_financial_state.ledger, tx)
			if bool(result.get("ok", false)):
				ledger_posted += 1
			else:
				for msg in result.get("errors", []):
					ledger_errors.append(str(msg))
	elif ledger_value != null:
		ledger_errors.append("ledger_tx must be an Array")

	var loop_impact: Dictionary = {}
	if ledger_errors.is_empty() and choice.has("loop_delta") and typeof(choice["loop_delta"]) == TYPE_DICTIONARY:
		loop_impact = _apply_loop_delta(choice["loop_delta"] as Dictionary)

	var statements := _finance.generate_statements_from_ledger(_financial_state)
	_financial_state.meta["financial_statements"] = statements
	var balance_sheet: Dictionary = statements.get("balance_sheet", {}) as Dictionary
	_financial_state.cash = float(balance_sheet.get("cash", _financial_state.cash))

	var feedback := str(choice.get("feedback", "Audit Room remediation applied."))
	if ledger_errors.is_empty():
		loop_state.memory["last_audit_room_feedback"] = feedback
		loop_state.memory["audit_room_remediation"] = {
			"remediation_id": remediation_id,
			"label": str(choice.get("label", remediation_id)),
			"week": get_current_decision_week(),
			"feedback": feedback
		}
		loop_state.flags["tool_used.AUDIT_ROOM"] = true

	_loop_system.call("notify_updated")

	var audit_impact := {
		"remediation_id": remediation_id,
		"ledger_posted": ledger_posted,
		"feedback": feedback,
		"errors": ledger_errors
	}
	var impacts := {
		"audit_room": audit_impact,
		"loop": loop_impact
	}
	emit_signal("decision_applied", "audit_room.%s" % remediation_id, impacts)
	return {
		"ok": ledger_errors.is_empty(),
		"impacts": impacts,
		"events": [],
		"errors": ledger_errors,
		"ui": {
			"feedback": feedback
		}
	}

func _apply_action_card_choice(card_id: String, choice_id: String, choice: Dictionary) -> Dictionary:
	var action_errors: Array[String] = []
	if card_id.strip_edges() == "":
		action_errors.append("Action card missing card_id")
	if choice_id.strip_edges() == "":
		action_errors.append("Action card missing choice_id")
	if _loop_system == null:
		action_errors.append("LoopSystem unavailable")
	if not action_errors.is_empty():
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": action_errors,
			"ui": {}
		}

	var loop_state: LoopState = _loop_system.call("get_state_ref") as LoopState
	var completed_flag := "card_completed.%s" % card_id
	if bool(loop_state.flags.get(completed_flag, false)):
		var duplicate_error := "Action card already completed: %s" % card_id
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": [duplicate_error],
			"ui": {"feedback": duplicate_error}
		}

	var requirements := _validate_choice_requirements(choice)
	if not bool(requirements.get("ok", false)):
		return {
			"ok": false,
			"impacts": {},
			"events": [],
			"errors": requirements.get("errors", []),
			"ui": {"feedback": str(requirements.get("feedback", "Choice requirements not met."))}
		}

	var posted := 0
	var ledger_errors: Array[String] = []
	var ledger_value: Variant = choice.get("ledger_tx", [])
	if typeof(ledger_value) == TYPE_ARRAY:
		var txs: Array = ledger_value as Array
		var base_index := int((_financial_state.ledger.get("transactions", []) as Array).size())
		for i in range(txs.size()):
			var tx_value: Variant = txs[i]
			if typeof(tx_value) != TYPE_DICTIONARY:
				ledger_errors.append("ledger_tx entry must be a Dictionary")
				continue
			var tx: Dictionary = (tx_value as Dictionary).duplicate(true)
			tx["tx_id"] = "ACTION_%s_%s_%s" % [card_id, choice_id, str(base_index + i).pad_zeros(4)]
			tx["week"] = get_current_decision_week()
			tx["source"] = "action_card"
			tx["card_id"] = card_id
			tx["choice_id"] = choice_id
			var result: Dictionary = _ledger.post_transaction(_financial_state.ledger, tx)
			if bool(result.get("ok", false)):
				posted += 1
			else:
				for msg in result.get("errors", []):
					ledger_errors.append(str(msg))
	elif ledger_value != null:
		ledger_errors.append("ledger_tx must be an Array")

	if choice.has("airport_delta") and typeof(choice["airport_delta"]) == TYPE_DICTIONARY:
		_apply_domain_delta(_financial_state.airport, choice["airport_delta"] as Dictionary, "airport")
	if choice.has("commercial_delta") and typeof(choice["commercial_delta"]) == TYPE_DICTIONARY:
		_apply_domain_delta(_financial_state.commercial, choice["commercial_delta"] as Dictionary, "commercial")
	if choice.has("economy_delta") and typeof(choice["economy_delta"]) == TYPE_DICTIONARY:
		_apply_domain_delta(_financial_state.economy, choice["economy_delta"] as Dictionary, "economy")

	var loop_impact: Dictionary = {}
	if choice.has("loop_delta") and typeof(choice["loop_delta"]) == TYPE_DICTIONARY:
		loop_impact = _apply_loop_delta(choice["loop_delta"] as Dictionary)

	var statements := _finance.generate_statements_from_ledger(_financial_state)
	_financial_state.meta["financial_statements"] = statements
	var balance_sheet: Dictionary = statements.get("balance_sheet", {}) as Dictionary
	_financial_state.cash = float(balance_sheet.get("cash", _financial_state.cash))

	var feedback := str(choice.get("feedback", "Decision applied."))
	loop_state.memory["last_action_feedback"] = feedback
	loop_state.flags[completed_flag] = true
	_loop_system.call("notify_updated")

	var action_impact := {
		"card_id": card_id,
		"choice_id": choice_id,
		"feedback": feedback,
		"ledger_posted": posted,
		"errors": ledger_errors
	}
	var impacts := {
		"action_card": action_impact,
		"loop": loop_impact
	}
	emit_signal("decision_applied", "action_card.%s" % card_id, impacts)
	return {
		"ok": ledger_errors.is_empty(),
		"impacts": impacts,
		"events": [],
		"errors": ledger_errors,
		"ui": {
			"feedback": feedback
		}
	}

func _validate_choice_requirements(choice: Dictionary) -> Dictionary:
	if not choice.has("requires") or typeof(choice["requires"]) != TYPE_DICTIONARY:
		return {"ok": true, "feedback": "", "errors": []}
	if _loop_system == null:
		return {
			"ok": false,
			"feedback": "Choice requirements cannot be checked.",
			"errors": ["LoopSystem unavailable"]
		}

	var requires: Dictionary = choice["requires"] as Dictionary
	var unavailable_feedback := str(requires.get("unavailable_feedback", "Choice requirements not met."))
	if requires.has("contract_review") and typeof(requires["contract_review"]) == TYPE_DICTIONARY:
		var contract_req: Dictionary = requires["contract_review"] as Dictionary
		var review_id := str(contract_req.get("review_id", ""))
		var field := str(contract_req.get("field", ""))
		if review_id.strip_edges() == "" or field.strip_edges() == "":
			return {
				"ok": false,
				"feedback": unavailable_feedback,
				"errors": ["Contract review requirement missing review_id or field"]
			}

		var loop_state: LoopState = _loop_system.call("get_state_ref") as LoopState
		var reviews_value: Variant = loop_state.memory.get("contract_reviews", {})
		if typeof(reviews_value) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"feedback": unavailable_feedback,
				"errors": ["Required contract review not found: %s" % review_id]
			}
		var reviews: Dictionary = reviews_value as Dictionary
		var review_value: Variant = reviews.get(review_id, {})
		if typeof(review_value) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"feedback": unavailable_feedback,
				"errors": ["Required contract review not found: %s" % review_id]
			}
		var review: Dictionary = review_value as Dictionary
		var actual: Variant = review.get(field, null)

		if contract_req.has("in") and typeof(contract_req["in"]) == TYPE_ARRAY:
			var allowed: Array = contract_req["in"] as Array
			var matched := false
			for allowed_value in allowed:
				if str(allowed_value) == str(actual):
					matched = true
					break
			if not matched:
				return {
					"ok": false,
					"feedback": unavailable_feedback,
					"errors": ["Contract review requirement failed: %s.%s" % [review_id, field]]
				}
		elif contract_req.has("equals"):
			if str(actual) != str(contract_req.get("equals")):
				return {
					"ok": false,
					"feedback": unavailable_feedback,
					"errors": ["Contract review requirement failed: %s.%s" % [review_id, field]]
				}

	return {"ok": true, "feedback": "", "errors": []}

func _upsert_contract_review_state(review_id: String, choice_id: String, contract_delta: Dictionary) -> Dictionary:
	if typeof(_financial_state.contracts) != TYPE_DICTIONARY:
		_financial_state.contracts = {}
	var active_value: Variant = _financial_state.contracts.get("active", [])
	var active: Array = []
	if typeof(active_value) == TYPE_ARRAY:
		active = active_value as Array

	var result := {
		"review_id": review_id,
		"choice_id": choice_id,
		"status": str(contract_delta.get("status", "")),
		"risk_rating": str(contract_delta.get("risk_rating", "")),
		"clawback_strength": str(contract_delta.get("clawback_strength", "")),
		"minimum_service_commitment": bool(contract_delta.get("minimum_service_commitment", false)),
		"week": get_current_decision_week()
	}

	var replaced := false
	for i in range(active.size()):
		var item_value: Variant = active[i]
		if typeof(item_value) == TYPE_DICTIONARY and str((item_value as Dictionary).get("review_id", "")) == review_id:
			active[i] = result.duplicate(true)
			replaced = true
			break
	if not replaced:
		active.append(result.duplicate(true))

	_financial_state.contracts["active"] = active
	return result

func get_current_decision_week() -> int:
	if _loop_system == null:
		return 1
	var state: LoopState = _loop_system.call("get_state_ref") as LoopState
	return int(state.week_number) + 1

func _advance_loop_time() -> Dictionary:
	if _loop_system == null:
		return {
			"week_number": 0,
			"month_number": 0,
			"week_in_month": 0,
			"is_month_end": false,
			"closed_month": 0
		}

	var state: LoopState = _loop_system.call("get_state_ref") as LoopState
	state.week_number += 1

	var is_month_end := (state.week_number % 4) == 0
	var closed_month := state.month_number
	if is_month_end:
		_last_month_report = _finance.close_month(_financial_state, closed_month)
		state.month_number += 1

	_loop_system.call("notify_updated")

	return {
		"week_number": state.week_number,
		"month_number": state.month_number,
		"week_in_month": ((state.week_number - 1) % 4) + 1 if state.week_number > 0 else 0,
		"is_month_end": is_month_end,
		"closed_month": closed_month
	}

func _apply_weekly_burn(weekly_opex: float) -> Dictionary:
	_financial_state.cash -= weekly_opex
	_financial_state.expense_ytd += weekly_opex
	_financial_state.expense_mtd += weekly_opex
	return {
		"cash_delta": -weekly_opex,
		"expense_delta": weekly_opex
	}

func _apply_weekly_finance() -> Dictionary:
	var module := str(_financial_state.meta.get("module", ""))
	var finance_mode := str(_financial_state.meta.get("finance_mode", "delta"))
	if module == "flightpath_airport" or finance_mode == "ledger":
		return _apply_airport_weekly_finance()

	# PATCH 1: disabled legacy airline behavior because Airport CFO is canonical v0.1.
	# Legacy airline delta mode remains available only for scenarios that do not opt into Flightpath ledger mode.
	var delta := _finance.calculate_week_delta(_financial_state)
	return _apply_financial_delta(delta)

func _apply_airport_weekly_finance() -> Dictionary:
	var loop_week := 1
	if _loop_system:
		var ls: LoopState = _loop_system.call("get_state_ref") as LoopState
		loop_week = int(ls.week_number) + 1
	var result: Dictionary = _finance.calculate_airport_week(_financial_state, loop_week)
	return result

func _apply_legacy_ledger_weekly_finance() -> Dictionary:
	# PATCH 1: disabled legacy airline behavior because Airport CFO is canonical v0.1.
	# Kept as an adapter for older Patch 2 tests that explicitly call post_week().
	var loop_week := 0
	if _loop_system:
		var ls: LoopState = _loop_system.call("get_state_ref") as LoopState
		loop_week = int(ls.week_number) + 1
	var result: Dictionary = _finance.post_week(_financial_state, {"week_number": loop_week})
	return result

func _apply_financial_delta(delta: Dictionary) -> Dictionary:
	var cash_delta := float(delta.get("cash_delta", 0.0))
	var revenue_delta := float(delta.get("revenue_delta", 0.0))
	var expense_delta := float(delta.get("expense_delta", 0.0))
	var ask_delta := float(delta.get("ask_delta", 0.0))
	var rpk_delta := float(delta.get("rpk_delta", 0.0))

	_financial_state.cash = float(_financial_state.cash) + cash_delta
	_financial_state.revenue_ytd = float(_financial_state.revenue_ytd) + revenue_delta
	_financial_state.expense_ytd = float(_financial_state.expense_ytd) + expense_delta
	_financial_state.revenue_mtd = float(_financial_state.revenue_mtd) + revenue_delta
	_financial_state.expense_mtd = float(_financial_state.expense_mtd) + expense_delta
	_financial_state.kpis["ask"] = float(_financial_state.kpis.get("ask", 0.0)) + ask_delta
	_financial_state.kpis["rpk"] = float(_financial_state.kpis.get("rpk", 0.0)) + rpk_delta

	return {
		"cash_delta": cash_delta,
		"revenue_delta": revenue_delta,
		"expense_delta": expense_delta,
		"ask_delta": ask_delta,
		"rpk_delta": rpk_delta
	}

func _apply_loop_delta(delta: Dictionary) -> Dictionary:
	if _loop_system == null:
		return {}

	var state: LoopState = _loop_system.call("get_state_ref") as LoopState

	if delta.has("hq_strength_delta"):
		state.hq_strength += float(delta["hq_strength_delta"])
	if delta.has("audit_pressure_delta"):
		state.audit_pressure += float(delta["audit_pressure_delta"])
	if delta.has("audit_score_delta"):
		state.audit_score += int(delta["audit_score_delta"])
	if delta.has("reputation_delta"):
		state.reputation += float(delta["reputation_delta"])
	if delta.has("ops_risk_delta"):
		state.ops_risk += float(delta["ops_risk_delta"])

	if delta.has("recruits_add"):
		for key in delta["recruits_add"].keys():
			state.recruits[key] = delta["recruits_add"][key]

	if delta.has("unlocks_add"):
		for key in delta["unlocks_add"].keys():
			state.unlocks[key] = delta["unlocks_add"][key]

	if delta.has("flags_set"):
		for key in delta["flags_set"].keys():
			state.flags[key] = delta["flags_set"][key]

	if delta.has("memory_set"):
		for key in delta["memory_set"].keys():
			state.memory[key] = delta["memory_set"][key]

	_loop_system.call("notify_updated")

	return {
		"hq_strength": state.hq_strength,
		"audit_pressure": state.audit_pressure,
		"audit_score": state.audit_score,
		"reputation": state.reputation,
		"ops_risk": state.ops_risk,
		"recruits": state.recruits,
		"unlocks": state.unlocks,
		"flags": state.flags,
		"memory": state.memory
	}

func _apply_domain_delta(root: Dictionary, delta: Dictionary, root_name: String) -> void:
	for key in delta.keys():
		var path := str(key)
		if path.begins_with(root_name + "."):
			path = path.substr(root_name.length() + 1)
		_apply_nested_numeric_delta(root, path, float(delta.get(key, 0.0)))

func _apply_nested_numeric_delta(root: Dictionary, dotted_path: String, delta: float) -> void:
	if dotted_path.strip_edges() == "":
		return
	var parts := dotted_path.split(".")
	var cursor := root
	for i in range(parts.size() - 1):
		var part := str(parts[i])
		if typeof(cursor.get(part, null)) != TYPE_DICTIONARY:
			cursor[part] = {}
		cursor = cursor[part] as Dictionary
	var leaf := str(parts[parts.size() - 1])
	cursor[leaf] = float(cursor.get(leaf, 0.0)) + delta
