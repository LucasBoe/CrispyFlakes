extends Camera2D

const zoomSpeed : float = 10
const minZoom: float = 0.5
const maxZoom: float = 6.0
const panBounds: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)


var zoomTarget : float = 1
var _camera_offset_base := Vector2.ZERO
var _shake_offset := Vector2.ZERO
var _shake_strength := 0.0
var _shake_decay := 0.0
var _rng := RandomNumberGenerator.new()

var camera_offset_base: Vector2:
	get:
		return _camera_offset_base
	set(value):
		_camera_offset_base = value
		_refresh_offset()

var drag_start_mouse_pos = Vector2.ZERO
var drag_start_camera_pos = Vector2.ZERO
var isDragging : bool = false
var zoomFactor : float = 1
var zoom_tween: Tween

func _ready():
	_rng.randomize()
	camera_offset_base = offset
	
	zoomTarget = 3
	zoom = Vector2(3,3)
	global_position = Vector2(0,0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	handle_zoom(delta)
	simple_pan(delta)
	click_and_drag()
	clamp_pan_to_bounds()
	_update_shake(delta)

func _refresh_offset() -> void:
	offset = _camera_offset_base + _shake_offset

func add_shake(strength := 4.0, duration := 0.12) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return

	_shake_strength = max(_shake_strength, strength)
	_shake_decay = max(_shake_decay, strength / duration)
	_update_shake_offset()

func _update_shake(delta: float) -> void:
	if _shake_strength <= 0.0:
		if _shake_offset != Vector2.ZERO:
			_shake_offset = Vector2.ZERO
			_refresh_offset()
		return

	_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
	_update_shake_offset()

func _update_shake_offset() -> void:
	if _shake_strength <= 0.0:
		_shake_offset = Vector2.ZERO
	else:
		_shake_offset = Vector2(
			int(round(_rng.randf_range(-_shake_strength, _shake_strength))),
			int(round(_rng.randf_range(-_shake_strength, _shake_strength)))
		)
	_refresh_offset()

func handle_zoom(delta):
	if Input.is_action_just_pressed("zoom_in"):
		zoomTarget *= 0.9
		zoom_in_out();

	if Input.is_action_just_pressed("zoom_out"):
		zoomTarget *= 1.1
		zoom_in_out();

func _unhandled_input(event):

	var delta = get_process_delta_time()

	#if event is InputEventMouseButton and event.is_pressed() and not event.is_echo():
		#if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			#zoomTarget *= 1.1
			#zoom_in_out();
		#elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			#zoomTarget *= 0.9
			#zoom_in_out();

	if event is InputEventPanGesture:
		if get_viewport().gui_get_hovered_control() != null:
			return
		if event.delta.y < 0:
			zoomTarget *= 1.005
			zoom_in_out();
		else:
			zoomTarget *= 0.99
			zoom_in_out();

func simple_pan(delta):
	var move_amount = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		move_amount.x += 1

	if Input.is_action_pressed("ui_left"):
		move_amount.x -= 1

	if Input.is_action_pressed("ui_up"):
		move_amount.y -= 1

	if Input.is_action_pressed("ui_down"):
		move_amount.y += 1

	move_amount = move_amount.normalized()
	position += move_amount * delta * 100 * (1/zoomFactor)

func clamp_pan_to_bounds() -> void:
	if panBounds.size == Vector2.ZERO:
		return

	var view := get_camera_world_rect()
	var bounds_end := panBounds.position + panBounds.size
	var view_end := view.position + view.size

	var shift := Vector2.ZERO

	# X
	if panBounds.size.x <= view.size.x:
		shift.x = (panBounds.position.x + panBounds.size.x * 0.5) - (view.position.x + view.size.x * 0.5)
	else:
		if view.position.x < panBounds.position.x:
			shift.x = panBounds.position.x - view.position.x
		elif view_end.x > bounds_end.x:
			shift.x = bounds_end.x - view_end.x

	# Y
	if panBounds.size.y <= view.size.y:
		shift.y = (panBounds.position.y + panBounds.size.y * 0.5) - (view.position.y + view.size.y * 0.5)
	else:
		if view.position.y < panBounds.position.y:
			shift.y = panBounds.position.y - view.position.y
		elif view_end.y > bounds_end.y:
			shift.y = bounds_end.y - view_end.y

	if shift != Vector2.ZERO:
		if isDragging:
			camera_offset_base += shift
			drag_start_camera_pos += shift
		else:
			global_position += shift

func click_and_drag():
	if !isDragging and Input.is_action_just_pressed("camera_pan"):
		drag_start_mouse_pos = get_viewport().get_mouse_position()
		drag_start_camera_pos = global_position
		isDragging = true

	if isDragging and Input.is_action_just_released("camera_pan"):
		isDragging = false

	if isDragging:
		var move_vector = get_viewport().get_mouse_position() - drag_start_mouse_pos
		global_position = drag_start_camera_pos - move_vector * (1.0 / zoomFactor)

func zoom_in_out(tween := false, duration := 0.15):
	zoomTarget = clampf(zoomTarget, minZoom, maxZoom)

	var mouse_position_before := get_global_mouse_position()
	var target_zoom := Vector2(zoomTarget, zoomTarget)

	if zoom_tween:
		zoom_tween.kill()

	if not tween:
		zoom = target_zoom
		var diff = mouse_position_before - get_global_mouse_position()
		camera_offset_base += diff
		return

	zoom_tween = create_tween().set_parallel(true)
	zoom_tween.tween_property(self, "zoom", target_zoom, duration)

func get_camera_world_rect() -> Rect2:
	var viewport := get_viewport_rect() # size in pixels

	var adjusted_size := viewport.size / zoom
	var center := global_position + camera_offset_base

	var top_left := center - adjusted_size / 2.0
	return Rect2(top_left, adjusted_size)

func tween_offset_to_zero() -> Tweener:
	return create_tween().tween_property(self, "camera_offset_base", Vector2.ZERO, 0.1)
