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

const PAN_MOVEMENT_THRESHOLD := 2.0
const ZOOM_MOVEMENT_THRESHOLD := 0.01

var _rows: Array[HBoxContainer] = []
var _completed: Dictionary = {}
var _camera: Camera2D
var _previous_camera_position := Vector2.ZERO
var _previous_camera_zoom := Vector2.ONE
var _previous_time_scale := 1.0
var _mouse_drag_start := Vector2.ZERO
var _tracking_mouse_drag := false
var _fade_tween: Tween

func _ready() -> void:
	set_process(true)
	_camera = get_viewport().get_camera_2d() as Camera2D
	if _camera != null:
		_previous_camera_position = _camera.global_position
		_previous_camera_zoom = _camera.zoom
	_previous_time_scale = Engine.time_scale
	TimeHandler.on_time_changed_signal.connect(_on_time_changed)

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

func _process(delta: float) -> void:
	if not visible:
		return

	if _camera == null:
		_camera = get_viewport().get_camera_2d() as Camera2D

	if _camera != null:
		if not _completed.get(ControlHint.PAN, false):
			if _camera.global_position.distance_to(_previous_camera_position) >= PAN_MOVEMENT_THRESHOLD:
				_complete(ControlHint.PAN)
		if not _completed.get(ControlHint.ZOOM, false):
			if abs(_camera.zoom.x - _previous_camera_zoom.x) >= ZOOM_MOVEMENT_THRESHOLD or abs(_camera.zoom.y - _previous_camera_zoom.y) >= ZOOM_MOVEMENT_THRESHOLD:
				_complete(ControlHint.ZOOM)
		_previous_camera_position = _camera.global_position
		_previous_camera_zoom = _camera.zoom

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT or mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				_tracking_mouse_drag = _can_track_mouse_drag()
				_mouse_drag_start = mouse_event.position
			else:
				_tracking_mouse_drag = false

	if event is InputEventMouseMotion and _tracking_mouse_drag:
		var motion_event := event as InputEventMouseMotion
		if motion_event.position.distance_to(_mouse_drag_start) >= DRAG_DISTANCE_TO_COMPLETE:
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

func _on_time_changed(time: float) -> void:
	if time != _previous_time_scale:
		_complete(ControlHint.TIME)
		_previous_time_scale = time
