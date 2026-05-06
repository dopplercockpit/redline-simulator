extends RefCounted

const SCENARIO_PATH := "res://data/scenarios/flightpath/scenario_001.json"
const ACTION_CARDS_PATH := "res://data/actions/flightpath/action_cards_v1.json"
const COA_PATH := "res://data/finance/coa_airport_v1.json"
const REQUIRED_ACCOUNTS := ["1000", "1200", "2000", "2100", "2300", "2400", "3000", "4000", "4100", "4200", "4300", "5000", "5100", "5200", "5300", "5600"]
const MISSION_PATHS := [
	"res://data/missions/month_close_v1.json",
	"res://data/missions/month_close_route_incentive_v1.json",
	"res://data/missions/month_close_compliance_v1.json"
]
const TOOL_PATHS := [
	"res://data/tools/debt_desk/debt_offers_v1.json",
	"res://data/tools/contract_review/contract_reviews_v1.json",
	"res://data/tools/audit_room/audit_remediations_v1.json"
]

func validate_runtime(game_manager: Node) -> Dictionary:
	var checks: Array = []
	_check_file_json(checks, "scenario_exists", SCENARIO_PATH, "Scenario file exists and parses.")
	var action_cards := _check_file_json(checks, "action_cards_exists", ACTION_CARDS_PATH, "Action cards file exists and parses.")
	_check_action_weeks(checks, action_cards)
	var coa := _check_file_json(checks, "coa_exists", COA_PATH, "COA file exists and parses.")
	_check_required_accounts(checks, coa)
	for path in MISSION_PATHS:
		_check_file_json(checks, "mission_%s" % path.get_file().get_basename(), path, "Mission file parses: %s" % path)
	for path in TOOL_PATHS:
		_check_file_json(checks, "tool_%s" % path.get_file().get_basename(), path, "Tool file parses: %s" % path)
	_check_runtime_state(checks, game_manager)

	var errors: Array[String] = []
	for check_value in checks:
		if typeof(check_value) != TYPE_DICTIONARY:
			continue
		var check: Dictionary = check_value as Dictionary
		if not bool(check.get("ok", false)):
			errors.append(str(check.get("message", check.get("id", "check failed"))))
	return {
		"ok": errors.is_empty(),
		"checks": checks,
		"errors": errors
	}

func _check_file_json(checks: Array, id: String, path: String, success_message: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		var missing := {"id": id, "ok": false, "message": "Missing file: %s" % path}
		checks.append(missing)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		var malformed := {"id": id, "ok": false, "message": "Malformed JSON: %s" % path}
		checks.append(malformed)
		return {}
	checks.append({"id": id, "ok": true, "message": success_message})
	return parsed as Dictionary

func _check_action_weeks(checks: Array, action_cards: Dictionary) -> void:
	var cards_value: Variant = action_cards.get("cards", [])
	if typeof(cards_value) != TYPE_ARRAY:
		checks.append({"id": "action_cards_weeks_1_12", "ok": false, "message": "Action cards missing cards array."})
		return
	var weeks: Dictionary = {}
	var cards: Array = cards_value as Array
	for card_value in cards:
		if typeof(card_value) == TYPE_DICTIONARY:
			weeks[int((card_value as Dictionary).get("week", 0))] = true
	var missing: Array[String] = []
	for week in range(1, 13):
		if not bool(weeks.get(week, false)):
			missing.append(str(week))
	if missing.is_empty():
		checks.append({"id": "action_cards_weeks_1_12", "ok": true, "message": "Action cards cover weeks 1 through 12."})
	else:
		checks.append({"id": "action_cards_weeks_1_12", "ok": false, "message": "Missing action card weeks: %s" % ", ".join(PackedStringArray(missing))})

func _check_required_accounts(checks: Array, coa: Dictionary) -> void:
	var accounts_value: Variant = coa.get("accounts", [])
	if typeof(accounts_value) != TYPE_ARRAY:
		checks.append({"id": "coa_required_accounts", "ok": false, "message": "COA missing accounts array."})
		return
	var found: Dictionary = {}
	var accounts: Array = accounts_value as Array
	for account_value in accounts:
		if typeof(account_value) == TYPE_DICTIONARY:
			found[str((account_value as Dictionary).get("code", ""))] = true
	var missing: Array[String] = []
	for gl in REQUIRED_ACCOUNTS:
		if not bool(found.get(gl, false)):
			missing.append(gl)
	if missing.is_empty():
		checks.append({"id": "coa_required_accounts", "ok": true, "message": "COA contains required accounts."})
	else:
		checks.append({"id": "coa_required_accounts", "ok": false, "message": "Missing GL accounts: %s" % ", ".join(PackedStringArray(missing))})

func _check_runtime_state(checks: Array, game_manager: Node) -> void:
	if game_manager == null:
		checks.append({"id": "game_manager", "ok": false, "message": "GameManager unavailable."})
		return
	var financial_state: GameStateData = null
	if game_manager.has_method("get_financial_state_ref"):
		financial_state = game_manager.call("get_financial_state_ref") as GameStateData
	checks.append({"id": "financial_state", "ok": financial_state != null, "message": "Financial state available." if financial_state != null else "Financial state missing."})
	var loop_state: LoopState = null
	if game_manager.has_method("get_loop_state_ref"):
		loop_state = game_manager.call("get_loop_state_ref") as LoopState
	checks.append({"id": "loop_state", "ok": loop_state != null, "message": "Loop state available." if loop_state != null else "Loop state missing."})
	if financial_state != null:
		checks.append({"id": "ledger_non_empty", "ok": not financial_state.ledger.is_empty(), "message": "Financial ledger is present." if not financial_state.ledger.is_empty() else "Financial ledger is empty."})
		checks.append({"id": "coa_loaded", "ok": not financial_state.coa.is_empty(), "message": "Financial COA is loaded." if not financial_state.coa.is_empty() else "Financial COA is empty."})
	if game_manager.has_method("get_loop_snapshot"):
		var snap: Dictionary = game_manager.call("get_loop_snapshot") as Dictionary
		checks.append({"id": "loop_snapshot_week_month", "ok": snap.has("week_number") and snap.has("month_number"), "message": "Loop snapshot includes week/month." if snap.has("week_number") and snap.has("month_number") else "Loop snapshot missing week/month."})
	checks.append({"id": "save_path", "ok": game_manager.has_method("get_save_path"), "message": "Save path API available." if game_manager.has_method("get_save_path") else "Save path API missing."})
	checks.append({"id": "export_path", "ok": game_manager.has_method("get_export_path"), "message": "Export path API available." if game_manager.has_method("get_export_path") else "Export path API missing."})
