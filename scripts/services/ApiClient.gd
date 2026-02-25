extends Node

signal email_generated(email_data)
signal reply_scored(result_data)

const BASE_URL := "http://127.0.0.1:8000"

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "AcademyHTTP"
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func generate_email() -> void:
	var body := {
		"difficulty": 1
	}
	_request("/v1/redline/email/generate", HTTPClient.METHOD_POST, body, "generate")

func submit_email_reply(email_id: String, reply_text: String) -> void:
	var body := {
		"email_id": email_id,
		"reply_text": reply_text
	}
	_request("/v1/redline/email/reply", HTTPClient.METHOD_POST, body, "reply")

func _request(endpoint: String, method: HTTPClient.Method, body: Dictionary, tag: String) -> void:
	var url := BASE_URL + endpoint
	var headers := ["Content-Type: application/json"]
	var body_json := JSON.stringify(body)
	_http.set_meta("request_tag", tag)
	var err := _http.request(url, headers, method, body_json)
	if err != OK:
		push_warning("ApiClient request error: %s" % err)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code < 200 or response_code >= 300:
		push_warning("ApiClient HTTP error: %s" % response_code)
		return

	var parsed := _parse_json(body)
	if parsed.is_empty():
		push_warning("ApiClient JSON parse failed")
		return

	var tag: String = str(_http.get_meta("request_tag", ""))
	match tag:
		"generate":
			emit_signal("email_generated", parsed)
		"reply":
			emit_signal("reply_scored", parsed)

func _parse_json(body: PackedByteArray) -> Dictionary:
	var json_string := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		return {}
	if json.data is Dictionary:
		return json.data as Dictionary
	return {}
