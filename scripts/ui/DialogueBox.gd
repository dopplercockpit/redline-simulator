# res://scripts/ui/DialogueBox.gd
extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

var dialogue_visible: bool = false
var hide_timer: float = 0.0
const AUTO_HIDE_TIME: float = 4.0

func _ready():
    print("DEBUG: DialogueBox initialized.")
    if panel:
        print("DEBUG: Panel node found.")
    else:
        print("ERROR: Panel node missing!")
    if label:
        print("DEBUG: Label node found.")
    else:
        print("ERROR: Label node missing!")
    hide_text()  # start hidden

func show_text(text: String):
    print("DEBUG: show_text called with -> ", text)
    if label:
        label.text = text
        print("DEBUG: Label text set successfully.")
    else:
        print("ERROR: Label node is null!")
    if panel:
        panel.visible = true
        print("DEBUG: Panel made visible.")
    else:
        print("ERROR: Panel node is null!")
    dialogue_visible = true
    hide_timer = 0.0

func hide_text():
    panel.visible = false
    dialogue_visible = false

func _process(delta):
    if dialogue_visible:
        hide_timer += delta
        if hide_timer > AUTO_HIDE_TIME:
            hide_text()
