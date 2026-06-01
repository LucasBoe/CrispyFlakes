extends Control

const IDLE_TEXTURE := preload("res://assets/sprites/ui/2x/click_cursor.png")
const CLICK_TEXTURE := preload("res://assets/sprites/ui/cursor_hint_click_sheet.png")
const FRAME_COUNT := 5
const CLICK_FRAME_DURATION := 0.06
const CLICK_BUTTONS := [
	MOUSE_BUTTON_LEFT,
	MOUSE_BUTTON_RIGHT,
	MOUSE_BUTTON_MIDDLE,
]
const CLICK_FRAME_TOP_OFFSETS := [0.0, 2.0, 1.0, 0.0, 0.0]

@onready var _cursor: TextureRect = $Cursor

var _click_frame_size := Vector2.ZERO
var _cursor_atlas := AtlasTexture.new()
var _cursor_offset := Vector2.ZERO
var _click_animation_active := false
var _click_animation_frame := 0
var _click_animation_timer := 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_click_frame_size = Vector2(
		float(CLICK_TEXTURE.get_width()) / FRAME_COUNT,
		float(CLICK_TEXTURE.get_height())
	)
	_cursor_atlas.atlas = CLICK_TEXTURE
	_show_idle_cursor()
	_sync_to_mouse_position()


func _process(delta: float) -> void:
	_sync_to_mouse_position()

	if not _click_animation_active:
		return

	_click_animation_timer -= delta
	while _click_animation_active and _click_animation_timer <= 0.0:
		_click_animation_frame += 1
		if _click_animation_frame >= FRAME_COUNT:
			_click_animation_active = false
			_set_cursor_frame(0)
			return

		_set_cursor_frame(_click_animation_frame)
		_click_animation_timer += CLICK_FRAME_DURATION


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index not in CLICK_BUTTONS:
		return

	_click_animation_active = true
	_click_animation_frame = 1
	_click_animation_timer = CLICK_FRAME_DURATION
	_set_cursor_frame(_click_animation_frame)


func _sync_to_mouse_position() -> void:
	_cursor.position = get_viewport().get_mouse_position() - (_cursor_offset * _cursor.scale)


func _set_cursor_frame(frame: int) -> void:
	if frame <= 0:
		_show_idle_cursor()
		return

	_cursor.texture = _cursor_atlas
	_cursor.size = _click_frame_size
	_cursor_offset = Vector2(0.0, CLICK_FRAME_TOP_OFFSETS[frame])
	_cursor_atlas.region = Rect2(
		_click_frame_size.x * frame,
		0.0,
		_click_frame_size.x,
		_click_frame_size.y
	)


func _show_idle_cursor() -> void:
	_cursor.texture = IDLE_TEXTURE
	_cursor.size = IDLE_TEXTURE.get_size()
	_cursor_offset = Vector2.ZERO
