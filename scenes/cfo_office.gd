extends Node2D


var cached_financials: Dictionary = {}

# find-or-spawn the FinancialPanel
#var financial_panel: Node = null
@onready var financial_panel: CanvasLayer = $FinancialPanel


# --- CONFIG ---
var backend_base := "" # MIDTERM: disable backend for web demo; use local JSON

# --- ON READY ---
func _ready() -> void:
	# Ensure FinancialPanel exists (either placed in scene or spawned here)
	financial_panel = get_node_or_null("FinancialPanel")
	if financial_panel == null:
		var fp_scene: PackedScene = preload("res://ui/FinancialPanel.tscn")
		financial_panel = fp_scene.instantiate()
		add_child(financial_panel)

	# Connect the signal from the panel
	if financial_panel and not financial_panel.is_connected("commentary_submitted", Callable(self, "_on_commentary_submitted")):
		financial_panel.connect("commentary_submitted", Callable(self, "_on_commentary_submitted"))

	if financial_panel and not financial_panel.analysis_submitted.is_connected(_on_analysis_submitted):
		financial_panel.analysis_submitted.connect(_on_analysis_submitted)



	# Normal startup
	_load_demo_financials()
	$Camera2D.make_current()
	$DialogueBox.show_text("System boot complete. Welcome to REVline Industries.")



func _ensure_news_panel() -> void:
	if not has_node("NewsPanel"):
		var p := preload("res://ui/NewsPanel.tscn").instantiate()
		add_child(p)

func _ensure_compendium_panel() -> void:
	if not has_node("CompendiumPanel"):
		var p := preload("res://ui/CompendiumPanel.tscn").instantiate()
		add_child(p)

func _load_demo_financials() -> void:
	var file_path := "res://data/redline_financials.json"
	if not FileAccess.file_exists(file_path):
		push_error("Missing demo_financials.json at " + file_path)
		return
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("Could not open demo_financials.json")
		return
	
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY and financial_panel and financial_panel.has_method("show_financials"):
		# handle both shapes: with/without "iteration"
		var payload: Variant = data
		if payload.has("iteration") and typeof(payload["iteration"]) == TYPE_DICTIONARY:
			payload = payload["iteration"]
		cached_financials = payload
	else:
		push_error("demo_financials.json parse failed or FinancialPanel missing")

# --- HOTSPOT EVENTS ---
func _on_hotspot_laptop_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		$DialogueBox.show_text("System online. Accessing mainframe…")
	
	if financial_panel:
		# toggle behavior: if already open, close it
		if financial_panel.visible:
			financial_panel.visible = false
			return
		# otherwise show it (populate first if we have cached data)
		if cached_financials.size() > 0:
			financial_panel.show_financials(cached_financials)
		financial_panel.visible = true

		# Optional: you can call show_financials(1) here when ready
		# show_financials(1) # removed: wrong script & wrong arg
		
func _on_hotspot_news_input_event(_vp: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_ensure_news_panel()
		$DialogueBox.show_text("Scanning markets…")
		$NewsPanel.load_news("res://data/news.json")
		$NewsPanel.visible = true

func _on_hotspot_bookcase_input_event(_vp: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_ensure_compendium_panel()
		$DialogueBox.show_text("Opening compendium…")
		$CompendiumPanel.load_compendium("res://data/compendium.json")
		$CompendiumPanel.visible = true

func _on_hotspot_mouse_entered() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_hotspot_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

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

#func _on_hotspot_laptop_mouse_entered() -> void:
#	print("Mouse entered laptop hotspot.")

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

func _on_commentary_submitted(text):
	var name = OS.get_environment("USERNAME")
	var path := "user://progress.log"
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		# file probably doesn't exist yet — create it
		file = FileAccess.open(path, FileAccess.WRITE)
	# move to end so we don't overwrite
	file.seek_end()
	file.store_line("%s | %s | %s" % [Time.get_datetime_string_from_system(), name, text])
	file.close()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if financial_panel and financial_panel.visible:
			financial_panel.visible = false
		if has_node("NewsPanel") and $NewsPanel.visible:
			$NewsPanel.visible = false
		if has_node("CompendiumPanel") and $CompendiumPanel.visible:
			$CompendiumPanel.visible = false

func _on_analysis_submitted(text: String) -> void:
	$DialogueBox.show_text("Analysis received. Nice hustle.")
	var path := "user://submissions.json"
	var arr: Array = []
	if FileAccess.file_exists(path):
		var rf: FileAccess = FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(rf.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			arr = parsed
	arr.append({
		"ts": Time.get_unix_time_from_system(),
		"analysis": text
	})
	var wf: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	wf.store_string(JSON.stringify(arr, "\t"))
