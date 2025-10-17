extends CanvasLayer
@onready var body: RichTextLabel = $PanelContainer/ScrollContainer/VBoxContainer/Body

func load_compendium(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		body.text = "[b]Missing compendium[/b]"
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		body.text = "[b]Malformed compendium[/b]"
		return

	var sections: Array = ["pricing","cogs","working_capital","risk","cash_flow","margin","inventory"]
	var t: String = ""
	for s in sections:
		if data.has(s):
			t += "[b]%s[/b]\n%s\n\n" % [s.capitalize(), str(data[s])]
	if t == "":
		t = "Compendium is empty. (Add FP&A bullets.)"
	body.text = t

func _ready() -> void:
	var btn: Button = $PanelContainer/ScrollContainer/VBoxContainer/Close
	btn.pressed.connect(func():
		visible = false
	)
