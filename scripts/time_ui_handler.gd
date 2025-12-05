extends Control

@onready var dummy = $HBoxContainer/Button

var buttons = []

func _ready():
	dummy.visible = false
	create_button(0, "res://assets/sprites/ui/time/time-button_pause.png")
	create_button(1, "res://assets/sprites/ui/time/time-button_play.png")
	create_button(3, "res://assets/sprites/ui/time/time-button_faster.png")
	create_button(9, "res://assets/sprites/ui/time/time-button_fastest.png")
	
	set_selected_button(buttons[1])
	
func create_button(speed, path):
	var instance : TimeButton = dummy.duplicate()
	dummy.get_parent().add_child(instance)
	buttons.append(instance)
	instance.visible = true
	instance.pressed.connect(set_selected_button.bind(instance))
	instance.pressed.connect(set_time.bind(speed))
	instance.iconTexture.texture = load(path)
	
func set_selected_button(b):
	SoundPlayer.mouse_click_down.play()
	for button : TimeButton in buttons:
		button.selected = button == b

func set_time(t):
	Engine.time_scale = t
