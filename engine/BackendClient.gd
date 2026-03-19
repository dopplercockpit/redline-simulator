extends Node
class_name BackendClient

signal news_request_finished(result: Dictionary)
signal inbox_request_finished(result: Dictionary)
signal nudge_request_finished(result: Dictionary)

const DEFAULT_BASE_URL := "http://127.0.0.1:8000"
const NEWS_ENDPOINT := "/v1/gen/news"
const INBOX_ENDPOINT := "/v1/gen/inbox"
const NUDGE_ENDPOINT := "/v1/coach/nudge"
const SCHEMA_VERSION := "1.0"

var base_url: String = ""
var _http: HTTPRequest
var _request_in_flight: bool = false

func _ready() -> void:
	base_url = _resolve_base_url()
	_http = HTTPRequest.new()
	_http.name = "BackendClientHTTP"
	_http.timeout = 5.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func fetch_news(context: Dictionary, payload: Dictionary) -> void:
	_post_envelope(NEWS_ENDPOINT, "news", context, payload)

func fetch_inbox(context: Dictionary, payload: Dictionary) -> void:
	_post_envelope(INBOX_ENDPOINT, "inbox", context, payload)

func fetch_nudge(context: Dictionary, payload: Dictionary) -> void:
	_post_envelope(NUDGE_ENDPOINT, "nudge", context, payload)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_kind: String = str(_http.get_meta("request_kind", ""))
	_request_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_request_failure(request_kind, "http_result_%s" % result)
		return
	if response_code < 200 or response_code >= 300:
		_emit_request_failure(request_kind, "http_status_%s" % response_code)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_emit_request_failure(request_kind, "invalid_json")
		return

	var response := parsed as Dictionary
	var result_block: Dictionary = response.get("result", {}) as Dictionary

	if request_kind == "news":
		var items_variant: Variant = result_block.get("items", [])
		if typeof(items_variant) != TYPE_ARRAY:
			_emit_request_failure(request_kind, "items_not_array")
			return

		var items: Array = items_variant as Array
		if items.is_empty():
			_emit_request_failure(request_kind, "items_empty")
			return

		emit_signal(
			"news_request_finished",
			{
				"ok": true,
				"items": items,
				"fallback_used": bool(response.get("fallback_used", false)),
				"status": str(response.get("status", "ok"))
			}
		)
		return

	if request_kind == "inbox":
		var message_variant: Variant = result_block.get("message", {})
		if typeof(message_variant) != TYPE_DICTIONARY:
			_emit_request_failure(request_kind, "message_not_object")
			return

		var message := message_variant as Dictionary
		emit_signal(
			"inbox_request_finished",
			{
				"ok": true,
				"message": message,
				"fallback_used": bool(response.get("fallback_used", false)),
				"status": str(response.get("status", "ok"))
			}
		)
		return

	if request_kind == "nudge":
		var nudge_variant: Variant = result_block.get("nudge", {})
		if typeof(nudge_variant) != TYPE_DICTIONARY:
			_emit_request_failure(request_kind, "nudge_not_object")
			return

		var nudge := nudge_variant as Dictionary
		emit_signal(
			"nudge_request_finished",
			{
				"ok": true,
				"nudge": nudge,
				"fallback_used": bool(response.get("fallback_used", false)),
				"status": str(response.get("status", "ok"))
			}
		)
		return

	_emit_request_failure(request_kind, "unknown_request_kind")


func _post_envelope(endpoint: String, request_kind: String, context: Dictionary, payload: Dictionary) -> void:
	if base_url.strip_edges() == "":
		_emit_request_failure(request_kind, "backend_base_url_missing")
		return

	if _request_in_flight:
		push_warning("BackendClient request skipped (%s in flight)." % request_kind)
		return

	var envelope := {
		"request_id": _make_request_id(request_kind),
		"schema_version": SCHEMA_VERSION,
		"client": context.get("client", _default_client_meta()),
		"scenario": context.get("scenario", _default_scenario_meta()),
		"run_context": context.get("run_context", _default_run_context()),
		"payload": payload
	}

	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s%s" % [base_url.rstrip("/"), endpoint]
	_http.set_meta("request_kind", request_kind)
	_request_in_flight = true
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(envelope))
	if err != OK:
		_request_in_flight = false
		var error_code := "request_failed_%s" % err
		_emit_request_failure(request_kind, error_code)


func _emit_request_failure(request_kind: String, error_code: String) -> void:
	var failure_payload := {"ok": false, "error": error_code, "status": "error", "fallback_used": true}
	if request_kind == "news":
		emit_signal("news_request_finished", failure_payload)
	elif request_kind == "inbox":
		emit_signal("inbox_request_finished", failure_payload)
	elif request_kind == "nudge":
		emit_signal("nudge_request_finished", failure_payload)
	else:
		push_warning("BackendClient failure for unknown request kind: %s" % request_kind)

func _resolve_base_url() -> String:
	var web_runtime_base := _resolve_web_runtime_base_url()
	if web_runtime_base.strip_edges() != "":
		return web_runtime_base

	if ProjectSettings.has_setting("application/config/backend_base_url"):
		return str(ProjectSettings.get_setting("application/config/backend_base_url", DEFAULT_BASE_URL))

	return DEFAULT_BASE_URL


func _resolve_web_runtime_base_url() -> String:
	# Web-first path: allow HTML shell runtime injection via window.REDLINE_CONFIG.API_BASE_URL.
	# Desktop/native skips this and uses project/default fallback behavior.
	if not OS.has_feature("web"):
		return ""

	var js_value: Variant = JavaScriptBridge.eval(
		"(window.REDLINE_CONFIG && window.REDLINE_CONFIG.API_BASE_URL) ? String(window.REDLINE_CONFIG.API_BASE_URL) : ''",
		true
	)
	return str(js_value).strip_edges()

func _make_request_id(prefix: String = "req") -> String:
	return "%s_%s_%s" % [prefix, str(Time.get_unix_time_from_system()), str(Time.get_ticks_msec())]

func _default_client_meta() -> Dictionary:
	return {
		"platform": OS.get_name().to_lower(),
		"build_version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
		"environment": "local"
	}

func _default_scenario_meta() -> Dictionary:
	return {
		"scenario_id": "unknown_scenario",
		"scenario_version": "1.0.0",
		"domain_module": "redline"
	}

func _default_run_context() -> Dictionary:
	return {
		"run_id": "local_run",
		"turn_index": 0,
		"week": 1,
		"month": 1,
		"quarter": 1,
		"year": 1,
		"seed": 0
	}
