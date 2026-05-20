extends Control
class_name PanCanvas

signal blank_left_clicked_signal
signal blank_right_clicked_signal

const DRAG_THRESHOLD := 6.0

var _dragging := false
var _drag_moved := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO

@onready var content: Control = $Content
 
func _ready() -> void:
	content.position.x = 100.0
	content.position.y = 32.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button_event.pressed:
				_dragging = true
				_drag_moved = false
				_drag_start_mouse = mouse_button_event.position
				_drag_start_pos = content.position
			else:
				if _dragging and not _drag_moved:
					blank_left_clicked_signal.emit()
				_dragging = false
				_drag_moved = false
		elif mouse_button_event.button_index == MOUSE_BUTTON_RIGHT and mouse_button_event.pressed:
			blank_right_clicked_signal.emit()
	elif event is InputEventMouseMotion and _dragging:
		var mouse_motion_event := event as InputEventMouseMotion
		var delta: Vector2 = mouse_motion_event.position - _drag_start_mouse
		if not _drag_moved and delta.length() >= DRAG_THRESHOLD:
			_drag_moved = true
		if _drag_moved:
			content.position = _drag_start_pos + delta
