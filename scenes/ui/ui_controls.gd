extends Control

const CHECKED_TEXTURE := preload("res://assets/sprites/ui/tutorial_todo_checked.png")
const DRAG_DISTANCE_TO_COMPLETE := 8.0
const CONTROL_HINTS: Array[String] = [
	"Use ARROW KEYS or CLICK and DRAG LEFT or MIDDLE MOUSE BUTTON to look around",
	"Use + / - or the MOUSE WHEEL to zoom in and out",
	"Click the TIME BUTTONS above or press 1, 2, 3 or 4 to speed up or pause the game",
]
enum ControlHint {
	PAN,
	ZOOM,
	TIME,
}

@onready var _container: VBoxContainer = %Container
@onready var _dummy: HBoxContainer = %Dummy

var _rows: Array[HBoxContainer] = []
var _completed: Dictionary = {}
var _mouse_drag_start := Vector2.ZERO
var _tracking_mouse_drag := false
var _fade_tween: Tween

func _ready() -> void:
	for index in CONTROL_HINTS.size():
		var row: HBoxContainer = _dummy if index == 0 else _dummy.duplicate()
		if index > 0:
			_container.add_child(row)

		var label := row.get_node("Label") as Label
		label.text = CONTROL_HINTS[index]
		label.custom_minimum_size.x = 420.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.show()
		_rows.append(row)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				_complete(ControlHint.PAN)
			KEY_1, KEY_2, KEY_3, KEY_4:
				_complete(ControlHint.TIME)

	if event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out"):
		_complete(ControlHint.ZOOM)

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				_tracking_mouse_drag = _can_track_mouse_drag()
				_mouse_drag_start = mouse_event.position
				if _is_time_button_hovered():
					_complete(ControlHint.TIME)
			else:
				_tracking_mouse_drag = false

	if event is InputEventMouseMotion and _tracking_mouse_drag:
		var motion_event := event as InputEventMouseMotion
		if motion_event.position.distance_to(_mouse_drag_start) >= DRAG_DISTANCE_TO_COMPLETE:
			_complete(ControlHint.PAN)
			_tracking_mouse_drag = false

func _complete(hint: int) -> void:
	if _completed.get(hint, false):
		return

	_completed[hint] = true
	var row := _rows[hint] if hint >= 0 and hint < _rows.size() else null
	if row != null:
		var icon := row.get_node("TextureRect") as TextureRect
		icon.texture = CHECKED_TEXTURE

	if _completed.size() >= CONTROL_HINTS.size():
		_fade_out()

func _fade_out() -> void:
	if _fade_tween != null:
		return

	_fade_tween = create_tween()
	_fade_tween.tween_interval(0.35)
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_fade_tween.tween_callback(hide)

func _can_track_mouse_drag() -> bool:
	return get_viewport().gui_get_hovered_control() == null

func _is_time_button_hovered() -> bool:
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is TimeButton:
			return true
		if control.name == "UITime":
			return true
		control = control.get_parent() as Control
	return false
