extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var rich: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/RichText
@onready var close_btn: Button = $Panel/VBoxContainer/HBoxContainer/CloseButton

var _base_text := ""

func _ready():
	visible = false
	close_btn.pressed.connect(_on_close)

func open_from_file(txt_path: String, highlight_terms: Array[String] = []):
	var f := FileAccess.open(txt_path, FileAccess.READ)
	if f:
		_base_text = f.get_as_text()
		f.close()
		var bb := _apply_highlight(_base_text, highlight_terms)
		rich.clear()
		rich.append_bbcode(bb)
		visible = true
		get_tree().paused = true

func _apply_highlight(text: String, terms: Array[String]) -> String:
	var bb := text
	# naive highlight: wrap each term with a yellow color tag
	for t in terms:
		if t.strip_edges() == "":
			continue
		var safe_t = RegEx.escape(t)
		var re := RegEx.new()
		re.compile("(?i)\\b" + safe_t + "\\b")
		var i := 0
		var out := ""
		var start := 0
		var m = re.search(text)
		while m:
			out += text.substr(start, m.get_start() - start)
			out += "[color=yellow][b]" + text.substr(m.get_start(), m.get_end() - m.get_start()) + "[/b][/color]"
			start = m.get_end()
			m = re.search(text, start)
		out += text.substr(start, text.length() - start)
		text = out
	return text

func _on_close():
	visible = false
	get_tree().paused = false
