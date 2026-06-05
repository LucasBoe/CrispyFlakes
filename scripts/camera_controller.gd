extends Camera2D

const zoomSpeed : float = 10
const minZoom: float = 0.5
const maxZoom: float = 6.0
const panBounds: Rect2 = Rect2(Vector2(-1920,-1080), Vector2(3840,2160))
const CAMERA_POSITION_SAVE_PATH := "user://camera_position.json"
const ZOOM_TAP_IN_MULTIPLIER := 0.9
const ZOOM_TAP_OUT_MULTIPLIER := 1.1
const ZOOM_HOLD_MULTIPLIER_PER_SECOND := 1.8
const PAN_SCREEN_SPEED := 100.0
const POSITION_SMOOTHING_SPEED := 10.0
const ZOOM_SMOOTHING_SPEED := 12.0
const OFFSET_SMOOTHING_SPEED := 14.0
const POSITION_SNAP_EPSILON := 0.01
const ZOOM_SNAP_EPSILON := 0.001
const FOCUS_LOCK_LERP_SPEED := 6.0
const CAMERA_POSITION_SAVE_PATH := "user://camera_position.json"


var zoomTarget : float = 1
var _camera_offset_base := Vector2.ZERO
var _camera_target_position := Vector2.ZERO
var _camera_target_offset_base := Vector2.ZERO
var _shake_offset := Vector2.ZERO
var _shake_strength := 0.0
var _shake_decay := 0.0
var _rng := RandomNumberGenerator.new()
var _last_shake_update_usec := 0

var camera_offset_base: Vector2:
	get:
		return _camera_offset_base
	set(value):
		_set_camera_offset_base_immediate(value)

var camera_target_offset_base: Vector2:
	get:
		return _camera_target_offset_base
	set(value):
		_camera_target_offset_base = value

var drag_start_mouse_pos = Vector2.ZERO
var drag_start_camera_pos = Vector2.ZERO
var isDragging : bool = false
var isLMBDragging : bool = false
var zoom_tween: Tween
var _focus_lock_owner = null
var _focus_lock_target: Node2D = null
var _focus_lock_offset := Vector2.ZERO
var _focus_lock_zoom := 2.0
var _focus_restore_position := Vector2.ZERO
var _focus_restore_zoom_target := 2.0
var _keyboard_zoom_in_pressed := false
var _keyboard_zoom_out_pressed := false
var _keyboard_zoom_in_just_pressed := false
var _keyboard_zoom_out_just_pressed := false

func _ready():
	Console.add_command("save_cam_pos", console_save_cam_pos, 0, 0, "Saves the current camera position and zoom.")
	Console.add_command("load_cam_pos", console_load_cam_pos, 0, 0, "Loads the saved camera position and zoom.")
	_rng.randomize()
	_last_shake_update_usec = Time.get_ticks_usec()
	camera_offset_base = offset
	
	zoomTarget = 2
	_snap_to_camera_state(Vector2(-24,-48), zoomTarget, Vector2.ZERO)

func console_save_cam_pos() -> void:
	var saved_position := global_position + camera_offset_base
	var saved_zoom := zoom.x
	var save_data := {
		"position": {
			"x": saved_position.x,
			"y": saved_position.y,
		},
		"zoom": saved_zoom,
	}

	var file := FileAccess.open(CAMERA_POSITION_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		Console.print_error("Failed to open %s for writing." % ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH))
		return

	file.store_string(JSON.stringify(save_data, "\t"))
	Console.print_line("Saved camera position (%.2f, %.2f) and zoom %.2f to %s." % [
		saved_position.x,
		saved_position.y,
		saved_zoom,
		ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH),
	])

func console_load_cam_pos() -> void:
	if not FileAccess.file_exists(CAMERA_POSITION_SAVE_PATH):
		Console.print_error("No saved camera position found at %s." % ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH))
		return

	var file := FileAccess.open(CAMERA_POSITION_SAVE_PATH, FileAccess.READ)
	if file == null:
		Console.print_error("Failed to open %s for reading." % ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		Console.print_error("Saved camera position is not valid JSON.")
		return

	var position_data = parsed.get("position", {})
	if not (position_data is Dictionary):
		Console.print_error("Saved camera position is missing position data.")
		return

	var saved_zoom := float(parsed.get("zoom", zoomTarget))
	var saved_position := Vector2(
		float(position_data.get("x", global_position.x)),
		float(position_data.get("y", global_position.y))
	)

	if zoom_tween:
		zoom_tween.kill()
		zoom_tween = null
	_focus_lock_owner = null
	_focus_lock_target = null
	isDragging = false
	isLMBDragging = false

	zoomTarget = clampf(saved_zoom, minZoom, maxZoom)
	_snap_to_camera_state(saved_position, zoomTarget, Vector2.ZERO)
	clamp_pan_to_bounds()
	Console.print_line("Loaded camera position (%.2f, %.2f) and zoom %.2f." % [
		global_position.x,
		global_position.y,
		zoomTarget,
	])

func console_save_cam_pos() -> void:
	var saved_position := global_position + camera_offset_base
	var saved_zoom := zoom.x
	var save_data := {
		"position": {
			"x": saved_position.x,
			"y": saved_position.y,
		},
		"zoom": saved_zoom,
	}

	var file := FileAccess.open(CAMERA_POSITION_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		Console.print_error("Failed to open %s for writing." % ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH))
		return

	file.store_string(JSON.stringify(save_data, "\t"))
	Console.print_line("Saved camera position (%.2f, %.2f) and zoom %.2f to %s." % [
		saved_position.x,
		saved_position.y,
		saved_zoom,
		ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH),
	])

func console_load_cam_pos() -> void:
	if not FileAccess.file_exists(CAMERA_POSITION_SAVE_PATH):
		Console.print_error("No saved camera position found at %s." % ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH))
		return

	var file := FileAccess.open(CAMERA_POSITION_SAVE_PATH, FileAccess.READ)
	if file == null:
		Console.print_error("Failed to open %s for reading." % ProjectSettings.globalize_path(CAMERA_POSITION_SAVE_PATH))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		Console.print_error("Saved camera position is not valid JSON.")
		return

	var position_data = parsed.get("position", {})
	if not (position_data is Dictionary):
		Console.print_error("Saved camera position is missing position data.")
		return

	var saved_zoom := float(parsed.get("zoom", zoomTarget))
	var saved_position := Vector2(
		float(position_data.get("x", global_position.x)),
		float(position_data.get("y", global_position.y))
	)

	if zoom_tween:
		zoom_tween.kill()
		zoom_tween = null
	_focus_lock_owner = null
	_focus_lock_target = null
	isDragging = false
	isLMBDragging = false

	zoomTarget = clampf(saved_zoom, minZoom, maxZoom)
	zoom = Vector2(zoomTarget, zoomTarget)
	camera_offset_base = Vector2.ZERO
	global_position = saved_position
	clamp_pan_to_bounds()
	Console.print_line("Loaded camera position (%.2f, %.2f) and zoom %.2f." % [
		global_position.x,
		global_position.y,
		zoomTarget,
	])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var unscaled_delta := _get_unscaled_delta()
	if _focus_lock_owner != null:
		_update_focus_lock(unscaled_delta)
		_reset_keyboard_zoom_state()
	elif _is_console_open():
		_reset_keyboard_zoom_state()
	else:
		handle_zoom(unscaled_delta)
		simple_pan(_get_pan_delta(delta, unscaled_delta))
		click_and_drag()
	clamp_pan_to_bounds()
	_apply_camera_smoothing(unscaled_delta)
	_update_shake(unscaled_delta)

func _refresh_offset() -> void:
	offset = _camera_offset_base + _shake_offset

func _set_camera_offset_base_immediate(value: Vector2) -> void:
	_camera_target_offset_base = value
	_camera_offset_base = value
	_refresh_offset()

func set_camera_target_position(target_position: Vector2) -> void:
	_camera_target_position = target_position

func _snap_to_camera_state(target_position: Vector2, target_zoom: float, target_offset_base: Vector2 = Vector2.ZERO) -> void:
	_camera_target_position = target_position
	_camera_target_offset_base = target_offset_base
	zoomTarget = clampf(target_zoom, minZoom, maxZoom)
	global_position = _camera_target_position
	zoom = Vector2(zoomTarget, zoomTarget)
	_camera_offset_base = _camera_target_offset_base
	_refresh_offset()

func _apply_camera_smoothing(unscaled_delta: float) -> void:
	if unscaled_delta <= 0.0:
		return

	global_position = _smooth_vector(global_position, _camera_target_position, POSITION_SMOOTHING_SPEED, unscaled_delta, POSITION_SNAP_EPSILON)
	var smoothed_zoom := _smooth_float(zoom.x, zoomTarget, ZOOM_SMOOTHING_SPEED, unscaled_delta, ZOOM_SNAP_EPSILON)
	zoom = Vector2(smoothed_zoom, smoothed_zoom)
	_camera_offset_base = _smooth_vector(_camera_offset_base, _camera_target_offset_base, OFFSET_SMOOTHING_SPEED, unscaled_delta, POSITION_SNAP_EPSILON)
	_refresh_offset()

func _smooth_vector(current: Vector2, target: Vector2, speed: float, delta: float, epsilon: float) -> Vector2:
	if current.distance_squared_to(target) <= epsilon * epsilon:
		return target
	return current.lerp(target, _smoothing_weight(speed, delta))

func _smooth_float(current: float, target: float, speed: float, delta: float, epsilon: float) -> float:
	if absf(current - target) <= epsilon:
		return target
	return lerpf(current, target, _smoothing_weight(speed, delta))

func _smoothing_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)

func _is_console_open() -> bool:
	return Console != null and Console.control != null and Console.control.visible

func _reset_keyboard_zoom_state() -> void:
	_keyboard_zoom_in_pressed = false
	_keyboard_zoom_out_pressed = false
	_keyboard_zoom_in_just_pressed = false
	_keyboard_zoom_out_just_pressed = false

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

func _get_unscaled_delta() -> float:
	var now_usec := Time.get_ticks_usec()
	if _last_shake_update_usec == 0:
		_last_shake_update_usec = now_usec
		return 0.0

	var delta_usec := now_usec - _last_shake_update_usec
	_last_shake_update_usec = now_usec
	return maxf(delta_usec / 1000000.0, 0.0)

func _get_pan_delta(delta: float, unscaled_delta: float) -> float:
	return unscaled_delta if Engine.time_scale <= 0.0 else delta

func _update_shake_offset() -> void:
	if _shake_strength <= 0.0:
		_shake_offset = Vector2.ZERO
	else:
		_shake_offset = Vector2(
			int(round(_rng.randf_range(-_shake_strength, _shake_strength))),
			int(round(_rng.randf_range(-_shake_strength, _shake_strength)))
		)
	_refresh_offset()

func handle_zoom(delta: float) -> void:
	var keyboard_zoom_multiplier := 1.0
	if _keyboard_zoom_in_just_pressed:
		keyboard_zoom_multiplier *= ZOOM_TAP_IN_MULTIPLIER
	if _keyboard_zoom_out_just_pressed:
		keyboard_zoom_multiplier *= ZOOM_TAP_OUT_MULTIPLIER

	if delta > 0.0:
		var hold_multiplier := pow(ZOOM_HOLD_MULTIPLIER_PER_SECOND, delta)
		if _keyboard_zoom_in_pressed and not _keyboard_zoom_in_just_pressed:
			keyboard_zoom_multiplier /= hold_multiplier
		if _keyboard_zoom_out_pressed and not _keyboard_zoom_out_just_pressed:
			keyboard_zoom_multiplier *= hold_multiplier

	if not is_equal_approx(keyboard_zoom_multiplier, 1.0):
		zoomTarget *= keyboard_zoom_multiplier
		zoom_in_out(false, 0.15, true)

	var pointer_zoom_multiplier := 1.0
	if Input.is_action_just_pressed("zoom_in") and not _keyboard_zoom_in_just_pressed:
		pointer_zoom_multiplier *= ZOOM_TAP_IN_MULTIPLIER
	if Input.is_action_just_pressed("zoom_out") and not _keyboard_zoom_out_just_pressed:
		pointer_zoom_multiplier *= ZOOM_TAP_OUT_MULTIPLIER

	if not is_equal_approx(pointer_zoom_multiplier, 1.0):
		zoomTarget *= pointer_zoom_multiplier
		zoom_in_out()

	_keyboard_zoom_in_just_pressed = false
	_keyboard_zoom_out_just_pressed = false

func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.echo:
		return

	if key_event.is_action_pressed("zoom_in"):
		_keyboard_zoom_in_just_pressed = not _keyboard_zoom_in_pressed
		_keyboard_zoom_in_pressed = true
	elif key_event.is_action_released("zoom_in"):
		_keyboard_zoom_in_pressed = false

	if key_event.is_action_pressed("zoom_out"):
		_keyboard_zoom_out_just_pressed = not _keyboard_zoom_out_pressed
		_keyboard_zoom_out_pressed = true
	elif key_event.is_action_released("zoom_out"):
		_keyboard_zoom_out_pressed = false

func _unhandled_input(event):
	if _is_console_open():
		return

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
	_camera_target_position += move_amount * delta * PAN_SCREEN_SPEED / maxf(zoom.x, 0.001)

func clamp_pan_to_bounds() -> void:
	if panBounds.size == Vector2.ZERO:
		return

	var view := _get_camera_world_rect(_camera_target_position, zoomTarget, _camera_target_offset_base)
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
		if isDragging or isLMBDragging:
			_camera_target_offset_base += shift
			drag_start_camera_pos += shift
		else:
			_camera_target_position += shift

func click_and_drag():
	if !isDragging and Input.is_action_just_pressed("camera_pan"):
		if get_viewport().gui_get_hovered_control() != null:
			return
		drag_start_mouse_pos = get_viewport().get_mouse_position()
		drag_start_camera_pos = _camera_target_position
		isDragging = true

	if isDragging and Input.is_action_just_released("camera_pan"):
		isDragging = false

	if isDragging:
		var move_vector = get_viewport().get_mouse_position() - drag_start_mouse_pos
		_camera_target_position = drag_start_camera_pos - move_vector / zoom.x

	if !isLMBDragging and Input.is_action_just_pressed("click"):
		var can_lmb_pan = NPCWorker.picked_up_npc == null \
			and not (HoverHandler.currently_hovered is NPCWorker) \
			and not PlacementHandler.is_placing \
			and get_viewport().gui_get_hovered_control() == null
		if can_lmb_pan:
			drag_start_mouse_pos = get_viewport().get_mouse_position()
			drag_start_camera_pos = _camera_target_position
			isLMBDragging = true

	if isLMBDragging and Input.is_action_just_released("click"):
		isLMBDragging = false

	if isLMBDragging:
		var move_vector = get_viewport().get_mouse_position() - drag_start_mouse_pos
		_camera_target_position = drag_start_camera_pos - move_vector / zoom.x

func zoom_in_out(tween := false, duration := 0.15, use_screen_center_focus := false):
	zoomTarget = clampf(zoomTarget, minZoom, maxZoom)
	if use_screen_center_focus:
		return

	var mouse_world_before := get_global_mouse_position()
	var viewport_mouse_offset := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
	var target_center := _camera_target_position + _camera_target_offset_base
	var target_center_after_zoom := mouse_world_before - viewport_mouse_offset / zoomTarget

	if zoom_tween:
		zoom_tween.kill()
		zoom_tween = null

	_camera_target_offset_base += target_center_after_zoom - target_center

func get_camera_world_rect() -> Rect2:
	return _get_camera_world_rect(global_position, zoom.x, camera_offset_base)

func _get_camera_world_rect(camera_position: Vector2, zoom_value: float, offset_base: Vector2) -> Rect2:
	var viewport := get_viewport_rect() # size in pixels

	var adjusted_size := viewport.size / maxf(zoom_value, 0.001)
	var center := camera_position + offset_base

	var top_left := center - adjusted_size / 2.0
	return Rect2(top_left, adjusted_size)

func tween_offset_to_zero() -> Tweener:
	return create_tween().set_ignore_time_scale(true).tween_property(self, "camera_target_offset_base", Vector2.ZERO, 0.1)

func push_focus_lock(owner, target: Node2D, target_zoom: float = 4.0, target_offset: Vector2 = Vector2.ZERO) -> void:
	if owner == null or not is_instance_valid(target):
		return

	if _focus_lock_owner == null:
		_focus_restore_position = _camera_target_position
		_focus_restore_zoom_target = zoomTarget

	_focus_lock_owner = owner
	_focus_lock_target = target
	_focus_lock_offset = target_offset
	_focus_lock_zoom = clampf(target_zoom, minZoom, maxZoom)
	isDragging = false
	isLMBDragging = false

func pop_focus_lock(owner) -> void:
	if _focus_lock_owner != owner:
		return

	_focus_lock_owner = null
	_focus_lock_target = null
	zoomTarget = _focus_restore_zoom_target
	_camera_target_position = _focus_restore_position
	_camera_target_offset_base = Vector2.ZERO

func _update_focus_lock(unscaled_delta: float) -> void:
	if not is_instance_valid(_focus_lock_target):
		_focus_lock_owner = null
		_focus_lock_target = null
		return

	zoomTarget = _focus_lock_zoom
	_camera_target_position = _focus_lock_target.global_position + _focus_lock_offset
	_camera_target_offset_base = Vector2.ZERO
