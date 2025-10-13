# res://scripts/ui/DialogueBox.gd
extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var label: Node = $Panel/Label  # Label OR RichTextLabel

var dialogue_visible: bool = false
var hide_timer: float = 0.0
const AUTO_HIDE_TIME: float = 4.0

func _ready():
	if panel == null:
		push_error("DialogueBox: Panel node missing!")
	if label == null:
		push_error("DialogueBox: Label node missing!")

func _process(delta: float) -> void:
	if dialogue_visible:
		hide_timer += delta
		if hide_timer > AUTO_HIDE_TIME:
			hide_text()

func _set_text(text: String) -> void:
	# If it's a RichTextLabel, use BBCode; if it's a Label, strip tags
	if label is RichTextLabel:
		var r: RichTextLabel = label
		r.bbcode_enabled = true
		r.clear()
		r.append_text(text)  # BBCode supported
		r.scroll_to_line(r.get_line_count() - 1)
	elif label is Label:
		var l: Label = label
		l.text = _strip_bbcode(text)
	else:
		# Fallback
		label.set("text", text)  # will no-op if unknown
	panel.visible = true
	dialogue_visible = true
	hide_timer = 0.0

func show_text(text: String) -> void:
	_set_text(text)

func hide_text() -> void:
	panel.visible = false
	dialogue_visible = false

func _strip_bbcode(s: String) -> String:
	# Very basic tag stripper, good enough for [b], [i], etc.
	return s.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "").replace("[u]", "").replace("[/u]", "")
