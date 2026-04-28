extends Control
class_name PanCanvas

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO

@onready var content: Control = $Content

func _ready() -> void:
	content.position.x = 100.0
	content.position.y = 100.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_start_mouse = event.position
			_drag_start_pos = content.position
	elif event is InputEventMouseMotion and _dragging:
		content.position = _drag_start_pos + (event.position - _drag_start_mouse)
