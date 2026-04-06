extends Control
class_name UICloseHandler

#TODO: replace with proper check

signal fullscreen_ui_close_signal

func _ready():
	gui_input.connect(_on_click)
	
func _on_click(event : InputEvent):
	if (event.is_action_pressed("click")):
		fullscreen_ui_close_signal.emit()
