extends Node2D

# --- CONFIG ---
var backend_base := "http://127.0.0.1:8000" # replace with your Render URL

# --- ON READY ---
func _ready():
	$Camera2D.make_current()
	$DialogueBox.show_text("System boot complete. Welcome back, CFO.")

# --- HOTSPOT EVENTS ---
func _on_hotspot_laptop_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		$DialogueBox.show_text("System online. Accessing mainframe…")
		# Optional: you can call show_financials(1) here when ready
		show_financials(1)

# --- NETWORK CALL: GET FINANCIALS ---
var _http_state: HTTPRequest

func show_financials(iteration: int) -> void:
	# Create or reuse a single HTTPRequest node for GET; connect first, then request.
	if _http_state == null:
		_http_state = HTTPRequest.new()
		add_child(_http_state)
	else:
		if _http_state.is_connected("request_completed", Callable(self, "_on_state_loaded")):
			_http_state.disconnect("request_completed", Callable(self, "_on_state_loaded"))

	_http_state.connect("request_completed", Callable(self, "_on_state_loaded"), CONNECT_ONE_SHOT)

	var url = backend_base + "/midterm/state?iteration_id=%d" % iteration
	_http_state.request(url)

func _on_state_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		$DialogueBox.show_text("[b]Backend error:[/b] %s" % str(response_code))
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if has_node("/root/CFOOffice/FinancialPanel"):
		$FinancialPanel.show_financials(data)	
	if typeof(data) != TYPE_DICTIONARY or data.get("iteration", null) == null:
		$DialogueBox.show_text("[b]Invalid server response[/b]")
		return
	var it = data["iteration"]
	var text := "[b]%s — %s[/b]\n[i]%s[/i]\n\n[b]Income Statement:[/b]\n%s\n\n[b]Balance Sheet:[/b]\n%s\n\n[b]Cash Flow:[/b]\n%s" % [
		data["company"], it["title"], it["narrative"],
		JSON.stringify(it["income_statement"]),
		JSON.stringify(it["balance_sheet"]),
		JSON.stringify(it["cash_flow"])
	]
	$DialogueBox.show_text(text)

func _on_hotspot_laptop_mouse_entered() -> void:
	print("Mouse entered laptop hotspot.")

# --- NETWORK CALL: POST COMMENTARY ---
func submit_commentary(iteration: int, commentary: String) -> void:
	var url = backend_base + "/midterm/analyze"
	var payload = {"iteration_id": iteration, "commentary": commentary}
	var json = JSON.stringify(payload)

	var req := HTTPRequest.new()
	add_child(req)
	req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, json)
	req.connect("request_completed", Callable(self, "_on_commentary_reviewed").bind(iteration), CONNECT_ONE_SHOT)

# --- CALLBACK: HANDLE RESPONSE ---
func _on_commentary_reviewed(result, response_code, headers, body, iteration):
	if response_code != 200:
		$DialogueBox.show_text("[b]Feedback error:[/b] %s" % str(response_code))
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) == TYPE_DICTIONARY and data.has("analysis"):
		$DialogueBox.show_text("[b]Analyst Panel Feedback (Iter %d):[/b]\n%s" % [iteration, data["analysis"]])
	else:
		$DialogueBox.show_text("[b]Invalid server response:[/b]\n%s" % str(data))
