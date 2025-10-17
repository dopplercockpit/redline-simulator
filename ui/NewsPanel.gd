extends CanvasLayer
@onready var body: RichTextLabel = $PanelContainer/ScrollContainer/VBoxContainer/Body

func load_news(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		body.text = "[b]No news found[/b]"
		return
	var data: Variant = JSON.parse_string(f.get_as_text())   # Explicitly typed to avoid "Variant inference" warning
	if typeof(data) != TYPE_ARRAY:
		body.text = "[b]Malformed news[/b]"
		return
	var t: String = ""
	for item in data:
		var title = str(item.get("title","Untitled"))
		var source = str(item.get("source","—"))
		var blurb = str(item.get("blurb",""))
		t += "[b]%s[/b]  [i](%s)[/i]\n%s\n\n" % [title, source, blurb]
	body.text = t

func _ready() -> void:
	var btn: Button = $PanelContainer/ScrollContainer/VBoxContainer/Close
	btn.pressed.connect(func():
		visible = false
	)
