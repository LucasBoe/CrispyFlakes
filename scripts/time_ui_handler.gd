extends Control

@onready var dummy = $HBoxContainer/Button

var buttons = []
var _speed_to_button: Dictionary = {}

func _ready():
	dummy.visible = false
	create_button(0, "res://assets/sprites/ui/2x/time/time-button_pause.png")
	create_button(1, "res://assets/sprites/ui/2x/time/time-button_play.png")
	create_button(3, "res://assets/sprites/ui/2x/time/time-button_faster.png")
	create_button(9, "res://assets/sprites/ui/2x/time/time-button_fastest.png")
	if not TimeHandler.on_requested_time_changed_signal.is_connected(_on_requested_time_changed):
		TimeHandler.on_requested_time_changed_signal.connect(_on_requested_time_changed)
	_select_button_for_speed(TimeHandler.get_requested_time())
	
func _unhandled_input(event):
	if _is_typing_in_text_input():
		return

	if event.is_action_released("toggle_pause"):
		var pause = Engine.time_scale > 0
		_request_time(0 if pause else 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_time_by_index(0)
			KEY_2: set_time_by_index(1)
			KEY_3: set_time_by_index(2)
			KEY_4: set_time_by_index(3)

func _is_typing_in_text_input() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is CodeEdit

func set_time_by_index(index: int):
	_request_time([0, 1, 3, 9][index])
	
func create_button(speed, path):
	var instance : TimeButton = dummy.duplicate()
	dummy.get_parent().add_child(instance)
	buttons.append(instance)
	_speed_to_button[speed] = instance
	instance.visible = true
	instance.pressed.connect(_on_time_button_pressed.bind(speed))
	instance.iconTexture.texture = load(path)
	
func set_selected_button(b):
	for button : TimeButton in buttons:
		button.selected = button == b

func _request_time(speed: int) -> void:
	SoundPlayer.play_ui_click_down()
	TimeHandler.set_time(speed)

func _on_time_button_pressed(speed: int) -> void:
	_request_time(speed)

func _on_requested_time_changed(speed: int) -> void:
	_select_button_for_speed(speed)

func _select_button_for_speed(speed: int) -> void:
	var button: TimeButton = _speed_to_button.get(speed, null) as TimeButton
	if button != null:
		set_selected_button(button)
