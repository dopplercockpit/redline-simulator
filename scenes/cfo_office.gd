extends Node2D

# ===========================
# CONFIG
# ===========================
const SUBMIT_WEBHOOK_URL := "https://script.google.com/macros/s/AKfycbw2XJuAMKD5Po9sEW3oAvQH251lIAsoWh3Ant-r8ZAK1iOI8OimUKouJy5esIn93pEz/exec"
var backend_base := "" # keep empty for web demo (no backend calls)

# ===========================
# STATE
# ===========================
var game_state: GameState = GameState.new()  # Airline operational state
var cached_financials: Dictionary = {}
var scenarios: Array = []
var current_scenario_index: int = 0
var current_scenario: Dictionary = {}

# ===========================
# NODES
# ===========================
@onready var financial_panel: CanvasLayer = $FinancialPanel
@onready var submit_http: HTTPRequest = $SubmitHTTP

# ===========================
# LIFECYCLE
# ===========================
func _ready() -> void:
	print("User data dir: ", OS.get_user_data_dir())

	# Ensure FinancialPanel exists
	if financial_panel == null:
		var fp_scene: PackedScene = preload("res://ui/FinancialPanel.tscn")
		financial_panel = fp_scene.instantiate()
		add_child(financial_panel)

	# Connect commentary submit
	_connect_financial_panel()

	# Initialize airline state with demo data
	_init_demo_airline_state()

	# Load scenarios
	_load_scenarios()

	# Flavor
	$DialogueBox.show_text("System boot complete. Welcome to RedLine Airlines.")
	$Camera2D.make_current()

	# GameController.game_started.connect(_on_game_started)
	# GameController.state_updated.connect(_on_state_updated)
	# GameController.decision_processed.connect(_on_decision_processed)

func _connect_financial_panel() -> void:
	if financial_panel and not financial_panel.commentary_submitted.is_connected(_on_commentary_submitted):
		financial_panel.commentary_submitted.connect(_on_commentary_submitted)

# ===========================
# PANELS (lazy spawn helpers)
# ===========================
func _ensure_news_panel() -> void:
	if not has_node("NewsPanel"):
		var p := preload("res://ui/NewsPanel.tscn").instantiate()
		add_child(p)

func _ensure_compendium_panel() -> void:
	if not has_node("CompendiumPanel"):
		var p := preload("res://ui/CompendiumPanel.tscn").instantiate()
		add_child(p)

# ===========================
# DEMO AIRLINE STATE
# ===========================
func _init_demo_airline_state() -> void:
	# Initialize with demo airline data
	game_state.cash = 5000000.0
	game_state.revenue_ytd = 0.0
	game_state.expense_ytd = 0.0

	# Demo fleet: A320ceo aircraft
	game_state.fleet = {
		"A320ceo": {
			"count": 4,
			"lease_usd_mpm": 220000.0,
			"hours_avail": 10.5,
			"age_avg": 8.2
		}
	}

	# Demo routes
	game_state.routes = {
		"LYS-BCN": {
			"weekly_freq": 10,
			"price_usd": 99,
			"capacity_seats": 180,
			"demand_idx": 0.76
		},
		"LYS-MAD": {
			"weekly_freq": 7,
			"price_usd": 120,
			"capacity_seats": 180,
			"demand_idx": 0.68
		}
	}

	# Fuel pricing
	game_state.fuel = {
		"price_usd_per_ton": 830.0,
		"hedge_pct": 0.2,
		"hedge_price": 700.0
	}

func _load_financials_from(path: String) -> void:
	if path == "" or not FileAccess.file_exists(path):
		push_warning("Financials not found: " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			# Load into game state instead of cached_financials
			game_state.load_config(parsed)

# ===========================
# HOTSPOTS
# ===========================
func _on_hotspot_laptop_input_event(_vp: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Hide scenario so UIs don't overlap
		if has_node("ScenarioPanel") and $ScenarioPanel.visible:
			$ScenarioPanel.visible = false

		# Toggle panel
		if financial_panel.visible:
			financial_panel.visible = false
			return

		# Get live financials from game state and show
		var live_financials = game_state.get_financial_summary()
		financial_panel.show_financials(live_financials)
		financial_panel.visible = true


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

# ===========================
# SCENARIOS
# ===========================
func _load_scenarios() -> void:
	var path := "res://data/redline_scenarios_v3.json"
	if not FileAccess.file_exists(path):
		push_warning("No scenarios JSON at: " + path)
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var j: Variant = JSON.parse_string(f.get_as_text())
	if typeof(j) != TYPE_DICTIONARY:
		push_warning("Malformed scenarios JSON")
		return
	var arr: Variant = j.get("scenarios", [])
	if typeof(arr) == TYPE_ARRAY and arr.size() > 0:
		scenarios = arr
		current_scenario_index = 0
		_show_current_scenario()

func _show_current_scenario() -> void:
	if scenarios.is_empty():
		return
	current_scenario = scenarios[current_scenario_index]
	if not has_node("ScenarioPanel"):
		var p := preload("res://ui/ScenarioPanel.tscn").instantiate()
		add_child(p)
	var title := str(current_scenario.get("title","Scenario"))
	var brief := str(current_scenario.get("brief",""))
	var objectives: Array = current_scenario.get("objectives", [])
	var tips: Array = current_scenario.get("tips", [])
	$ScenarioPanel.set_brief(title, brief, objectives, tips)
	$ScenarioPanel.visible = true
	
	var fin_ref: String = str(current_scenario.get("starting_financials_ref", ""))
	if fin_ref != "":
		_load_financials_from(fin_ref)


func _advance_scenario() -> void:
	if scenarios.is_empty():
		return

	current_scenario_index += 1
	if current_scenario_index >= scenarios.size():
		$DialogueBox.show_text("All scenarios complete. Nice driving.")
		current_scenario_index = scenarios.size() - 1
		return

	_show_current_scenario()

	# 🔥 Load new scenario’s financials
	var fin_ref: String = str(current_scenario.get("starting_financials_ref", ""))
	if fin_ref != "":
		_load_financials_from(fin_ref)

	# 🔄 Force-refresh all panels that use scenario data
	if has_node("FinancialPanel") and is_instance_valid($FinancialPanel):
		var live_financials = game_state.get_financial_summary()
		$FinancialPanel.show_financials(live_financials)
		$FinancialPanel.reset_for_next_scenario()
		$FinancialPanel.submit_button.disabled = false


	if has_node("NewsPanel") and is_instance_valid($NewsPanel):
		$NewsPanel.load_news("res://data/news.json")

	if has_node("CompendiumPanel") and is_instance_valid($CompendiumPanel):
		$CompendiumPanel.load_compendium("res://data/compendium.json")

	# ✅ Tell player scenario changed
	var title := str(current_scenario.get("title","Next Scenario"))
	$DialogueBox.show_text("Scenario advanced: " + title)



# ===========================
# SUBMISSION HANDLING
# ===========================
func _on_commentary_submitted(text: String) -> void:
	# A) Get student name from panel (required)
	var student := ""
	if is_instance_valid(financial_panel) and financial_panel.has_method("get_student_name"):
		student = financial_panel.get_student_name()
	if student.strip_edges() == "":
		$DialogueBox.show_text("Please enter your name before submitting.")
		return

	# B) Local log to user:// (desktop + HTML5 sandbox)
	var path := "user://submissions.json"
	var arr: Array = []
	if FileAccess.file_exists(path):
		var rf: FileAccess = FileAccess.open(path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(rf.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			arr = parsed
	var entry := {
		"ts": Time.get_unix_time_from_system(),
		"student_name": student,
		"scenario_id": str(current_scenario.get("id","")),
		"scenario_title": str(current_scenario.get("title","")),
		"analysis": text
	}
	arr.append(entry)
	var wf: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	wf.store_string(JSON.stringify(arr, "\t"))

	# C) POST to Google Sheet Apps Script
	if has_node("SubmitHTTP"):
		var headers := ["Content-Type: application/json"]
		var body := JSON.stringify(entry)
		var err := submit_http.request(SUBMIT_WEBHOOK_URL, headers, HTTPClient.METHOD_POST, body)
		if err != OK:
			push_warning("Submit HTTP error: %s" % err)

	# D) UX + advance
	var full_path := OS.get_user_data_dir().path_join("submissions.json")
	$DialogueBox.show_text("Submission saved.\nLocal log:\n" + full_path + "\nSending to instructor…")
	_advance_scenario()

	# Close & reset the panel for the next scenario
	if is_instance_valid(financial_panel):
		financial_panel.reset_for_next_scenario()
		financial_panel.visible = false

	# Advance to the next scenario (keep your existing method if you already have it)
	if has_method("_advance_scenario"):
		_advance_scenario()


func _on_submit_http_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code >= 200 and response_code < 300:
		print("Submit webhook OK: ", response_code)
	else:
		push_warning("Submit webhook failed: %s" % response_code)

# ===========================
# ESC to close open panels
# ===========================
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(financial_panel) and financial_panel.visible:
			financial_panel.visible = false
		if has_node("NewsPanel") and $NewsPanel.visible:
			$NewsPanel.visible = false
		if has_node("CompendiumPanel") and $CompendiumPanel.visible:
			$CompendiumPanel.visible = false

# =====================================================
# SECTION 8: CFO OFFICE SCENE UPDATE
# Update your existing cfo_office.gd
# =====================================================


func _on_game_started(session_id: String):
	$DialogueBox.show_text("Game started! Session: " + session_id)

func _on_state_updated(state: Dictionary):
	# Update UI with new state
	if financial_panel:
		var financials = {
			"cash": state.get("cash", 0),
			"revenue_mtd": state.get("revenue_mtd", 0),
			"costs_mtd": state.get("costs_mtd", 0),
			"kpis": state.get("kpis", {})
		}
		financial_panel.update_display(financials)

func _on_decision_processed(impacts: Dictionary):
	$DialogueBox.show_text("Decision applied! Impact: " + str(impacts))
