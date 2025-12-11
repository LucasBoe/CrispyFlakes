extends PanelContainer
class_name FullscreenDragable

@onready var drag_button : Button = $ButtonDrag
@onready var close_button : Button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/ButtonClose

var drag_offset

func _ready():
	close_button.pressed.connect(hide)
	drag_button.button_down.connect(_on_start_drag)
	
func _on_start_drag():
	drag_offset = global_position - get_global_mouse_position()
	
func _process(delta):
	if not drag_button.button_pressed:
		return
		
	global_position = get_global_mouse_position() + drag_offset
