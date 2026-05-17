extends Node2D

@onready var sky = $Sky
@onready var clouds = $CloudHandler
@onready var mountains = [$Montains, $Montains2]
@onready var fullscreen_darken = $FulllscreenDarkenRect

const _FULLSCREEN_DARKEN_SHOW_ALPHA := 1.0

var mointain_lerp = Vector2(.33, .1)

var mountains_default_posisitions = []
var _fullscreen_darken_from_alpha := 0.0
var _fullscreen_darken_target_alpha := 0.0
var _fullscreen_darken_fade_start_usec := 0
var _fullscreen_darken_fade_duration := 0.0

func _ready():
	for i in mountains:
		mountains_default_posisitions.append(i.global_position)
	_setup_world_tint()
	fullscreen_darken.modulate.a = 0.0
	fullscreen_darken.hide()

func _setup_world_tint() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/world_tint.gdshader")
	rect.material = mat
	layer.add_child(rect)

func _process(_delta):
	_update_fullscreen_darken()
	var tod: float = fmod(Global.time_now, Global.DAY_DURATION) / Global.DAY_DURATION * 24.0
	$NewSky.material.set_shader_parameter("time_of_day", tod)
	RenderingServer.global_shader_parameter_set("sky_time_of_day", tod)
	var cam_pos = Camera.global_position + Camera.camera_offset_base
	var inv_zoom: Vector2 = Vector2.ONE / Camera.zoom
	sky.global_position = cam_pos
	sky.scale = Vector2(1000.0, inv_zoom.y)
	clouds.global_position = cam_pos
	clouds.scale = inv_zoom

	for i in mountains.size():
		var mountain = mountains[i]
		var default_position = mountains_default_posisitions[i]
		mountain.global_position = Vector2(lerp(default_position.x, cam_pos.x, mointain_lerp.x), lerp(default_position.y, cam_pos.y, mointain_lerp.y))
		mountain.scale = Vector2(lerp(1.0, inv_zoom.x, mointain_lerp.x), lerp(1.0, inv_zoom.y, mointain_lerp.y))

func fade_fullscreen_darken_in(duration: float = 0.28) -> void:
	_fade_fullscreen_darken_to(_FULLSCREEN_DARKEN_SHOW_ALPHA, duration)

func fade_fullscreen_darken_out(duration: float = 0.18) -> void:
	_fade_fullscreen_darken_to(0.0, duration)

func _fade_fullscreen_darken_to(target_alpha: float, duration: float) -> void:
	var clamped_alpha := clampf(target_alpha, 0.0, _FULLSCREEN_DARKEN_SHOW_ALPHA)
	_fullscreen_darken_from_alpha = fullscreen_darken.modulate.a
	_fullscreen_darken_target_alpha = clamped_alpha
	_fullscreen_darken_fade_duration = maxf(duration, 0.0)
	_fullscreen_darken_fade_start_usec = Time.get_ticks_usec()

	if clamped_alpha > 0.0:
		fullscreen_darken.show()

	if _fullscreen_darken_fade_duration <= 0.0:
		_set_fullscreen_darken_alpha(_fullscreen_darken_target_alpha)

func _update_fullscreen_darken() -> void:
	if is_zero_approx(fullscreen_darken.modulate.a - _fullscreen_darken_target_alpha) and _fullscreen_darken_fade_duration <= 0.0:
		return

	if _fullscreen_darken_fade_duration <= 0.0:
		_set_fullscreen_darken_alpha(_fullscreen_darken_target_alpha)
		return

	var elapsed := maxf((Time.get_ticks_usec() - _fullscreen_darken_fade_start_usec) / 1000000.0, 0.0)
	var progress := clampf(elapsed / _fullscreen_darken_fade_duration, 0.0, 1.0)
	var alpha := lerpf(_fullscreen_darken_from_alpha, _fullscreen_darken_target_alpha, progress)
	_set_fullscreen_darken_alpha(alpha)
	if progress >= 1.0:
		_fullscreen_darken_fade_duration = 0.0

func _set_fullscreen_darken_alpha(alpha: float) -> void:
	fullscreen_darken.modulate.a = clampf(alpha, 0.0, _FULLSCREEN_DARKEN_SHOW_ALPHA)
	if fullscreen_darken.modulate.a <= 0.0:
		fullscreen_darken.hide()
	else:
		fullscreen_darken.show()
