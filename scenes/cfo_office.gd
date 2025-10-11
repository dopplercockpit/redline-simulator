extends Node2D

# --- CONFIG ---
var backend_base := "https://redline-sim-backend.onrender.com" # replace with your Render URL

# --- ON READY ---
func _ready():
	$Camera2D.make_current()
	$DialogueBox.show_text("System boot complete. Welcome back, CFO.")

# --- HOTSPOT EVENTS ---
func _on_hotspot_laptop_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		$DialogueBox.show_text("System online. Accessing mainframe…")
		# Optional: you can call show_financials(1) here when ready
		# show_financials(1)

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
