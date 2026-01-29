extends Control
class_name UIDialogueHandler

@onready var root = $MarginContainer
@onready var dialogue_text_label = $MarginContainer/MarginContainer/MarginContainer/Label
@onready var dialogue_next_button = $MarginContainer/MarginContainer/Button

var current_target
signal on_text_finished_signal

func _ready():
	dialogue_next_button.pressed.connect(finish_dialogue)
	hide()
	
func print_dialogue(text, target_object):
	current_target = target_object
	dialogue_text_label.text = text
	show()
	await on_text_finished_signal

func finish_dialogue():
	on_text_finished_signal.emit()
	hide()

func _process(delta):
	if current_target == null:
		return
		
	var pos = Util.world_to_ui_position(current_target.global_position - Vector2(0, 24), self, %Camera)
	pos -= Vector2(0, root.size.y)
	root.global_position = pos
