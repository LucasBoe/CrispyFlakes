extends PanelContainer
class_name UIConfirm

@onready var body_text_label : RichTextLabel = $MarginContainer/MarginContainer/VBoxContainer/RichTextLabel
@onready var button_yes : Button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/ButtonYes
@onready var button_no : Button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/ButtonNo

var _action_if_yes

func _ready():
	button_yes.pressed.connect(click_yes)
	button_no.pressed.connect(click_no)
	hide()
	
func show_dialogue(text, action_if_yes):
	body_text_label.text = text
	_action_if_yes = action_if_yes
	show()
	
func click_yes():
	SoundPlayer.mouse_click_up.play()
	hide()
	
	if (_action_if_yes):
		_action_if_yes.call()
	
func click_no():
	SoundPlayer.mouse_click_up.play()
	hide()
