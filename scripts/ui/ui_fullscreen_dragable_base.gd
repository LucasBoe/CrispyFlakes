extends Control
class_name FullscreenDragable

@onready var drag_button : Button = $ButtonDrag
@onready var close_button : Button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/ButtonClose

var drag_offset = Vector2.ZERO

func _ready():
	drag_button.button_down.connect(_on_start_drag)

	if close_button:
		close_button.pressed.connect(hide)
	
func _on_start_drag():
	drag_offset = global_position - get_global_mouse_position()
	
func _process(delta):
	if not drag_button.button_pressed:
		return
		
	global_position = get_global_mouse_position() + drag_offset
