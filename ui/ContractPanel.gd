extends CanvasLayer
@onready var body: RichTextLabel = $PanelContainer/ScrollContainer/VBoxContainer/Body

func load_contract_template(path: String, vars: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		body.bbcode_text = "[b]Missing contract template[/b]\n" + path
		return

	var text: String = f.get_as_text()
	for key in vars.keys():
		var placeholder := "[" + str(key) + "]"
		text = text.replace(placeholder, str(vars.get(key, "[MISSING]")))

	var missing_re := RegEx.new()
	missing_re.compile("\\[[A-Z0-9_]+\\]")
	text = missing_re.sub(text, "[MISSING]", true)
	body.bbcode_text = "[code]" + text + "[/code]"

func _ready() -> void:
	var btn: Button = $PanelContainer/ScrollContainer/VBoxContainer/Close
	btn.pressed.connect(func():
		visible = false
	)
