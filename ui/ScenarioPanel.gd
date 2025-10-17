extends CanvasLayer
@onready var title: Label = $PanelContainer/ScrollContainer/VBox/Title
@onready var body: RichTextLabel = $PanelContainer/ScrollContainer/VBox/Body
@onready var close_btn: Button = $PanelContainer/ScrollContainer/VBox/Close

func set_brief(title_text: String, brief: String, objectives: Array, tips: Array) -> void:
	title.text = title_text
	var t: String = "[b]Brief[/b]\n%s\n\n[b]Objectives[/b]\n" % brief
	for o in objectives:
		t += "• %s\n" % str(o)
	if tips.size() > 0:
		t += "\n[b]Tips[/b]\n"
		for tip in tips:
			t += "• %s\n" % str(tip)
	body.text = t

func _ready() -> void:
	close_btn.pressed.connect(func(): visible = false)
	title.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
