# =====================================================
# SECTION 3: FRONTEND - GODOT GAME CONTROLLER
# File: scenes/GameController.gd
# =====================================================

# scenes/GameController.gd
extends Node

signal game_started(session_id: String)
signal state_updated(state: Dictionary)
signal decision_processed(result: Dictionary)

const API_BASE_URL := "http://localhost:8000"

var session_id: String = ""
var current_state: Dictionary = {}
var http_game: HTTPRequest

func _ready() -> void:
	http_game = HTTPRequest.new()
	http_game.name = "HTTPGame"
	add_child(http_game)
	http_game.request_completed.connect(_on_http_game_completed)

func start_new_game(player_name: String, scenario_id: String) -> void:
	var body := {
		"player_name": player_name,
		"scenario_id": scenario_id
	}
	
	_api_request("/game/new", HTTPClient.METHOD_POST, body, "new_game")

func advance_time(days: int = 1) -> void:
	if session_id == "":
		return
	
	_api_request(
		"/game/" + session_id + "/tick",
		HTTPClient.METHOD_POST,
		{"days": days},
        "tick"
	)

func make_decision(decision_type: String, parameters: Dictionary) -> void:
	if session_id == "":
		return
	
	var body := {
		"decision_type": decision_type,
		"parameters": parameters
	}
	
	_api_request(
		"/game/" + session_id + "/decision",
		HTTPClient.METHOD_POST,
		body,
        "decision"
	)

func _api_request(endpoint: String, method: HTTPClient.Method, body: Dictionary, tag: String) -> void:
	var url := API_BASE_URL + endpoint
	var headers := ["Content-Type: application/json"]
	var body_json := JSON.stringify(body)
	
	http_game.set_meta("request_tag", tag)
	http_game.request(url, headers, method, body_json)

func _on_http_game_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_error("API error: " + str(response_code))
		return
	
	var response := _parse_json_response(body)
	var tag: String = http_game.get_meta("request_tag", "")
	
	match tag:
		"new_game":
			session_id = response.get("session_id", "")
			current_state = response
			emit_signal("game_started", session_id)
			emit_signal("state_updated", current_state)
		
		"tick":
			current_state = response
			emit_signal("state_updated", current_state)
		
		"decision":
			emit_signal("decision_processed", response.get("impacts", {}))
			current_state = response.get("new_state", {})
			emit_signal("state_updated", current_state)

func _parse_json_response(body: PackedByteArray) -> Dictionary:
	var json_string := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		return {}
	
	return json.data
