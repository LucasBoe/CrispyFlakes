extends Node2D
class_name StoveInfrastructure

signal on_destroy_signal

const MAX_FUEL_DURATION := 60.0
const EMBER_DURATION := 8.0
const REFUEL_THRESHOLD_RATIO := 0.2
const LOW_FUEL_VISIBILITY_RATIO := 0.25
const REFUEL_DURATION := 2.5
const HEAT_RANGE := 144.0
const VISUAL_OFFSET := Vector2(8, -22)

const EMBER_MODULATE := Color(0.85, 0.68, 0.52, 1.0)
const INACTIVE_MODULATE := Color(0.8, 0.8, 0.8, 1.0)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _progress_bar: TextureProgressBar = $ProgressBar
@onready var _selectable_area: Area2D = $SelectableArea

@onready var _stove_on_texture = preload("res://assets/sprites/stove.png")
@onready var _stove_off_texure = preload("res://assets/sprites/stove_off.png")

var room_index: Vector2i = Vector2i.ZERO
var data = null
var worker: NPCWorker = null

var _fuel_remaining := 0.0
var _ember_remaining := 0.0
var _hovered := false
var _selected := false
var _aura_time := 0.0

var _warmth_light: PointLight2D = null
var _smoke_particles: CPUParticles2D = null
var _aura_sprite: Sprite2D = null

func _ready() -> void:
	if _sprite.material is ShaderMaterial:
		_sprite.material = (_sprite.material as ShaderMaterial).duplicate(true)
	_setup_warmth_light()
	_setup_smoke_particles()
	_setup_aura()
	_apply_outline()
	_refresh_visual_state()
	_refresh_progress_bar()
	TemperatureHandler.register_source(self)

func _setup_warmth_light() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_warmth_light = PointLight2D.new()
	_warmth_light.texture = tex
	_warmth_light.texture_scale = 2.5
	_warmth_light.color = Color(1.0, 0.55, 0.2)
	_warmth_light.energy = 0.5
	_warmth_light.enabled = false
	add_child(_warmth_light)

func _setup_smoke_particles() -> void:
	_smoke_particles = CPUParticles2D.new()
	_smoke_particles.emitting = false
	_smoke_particles.amount = 8
	_smoke_particles.lifetime = 1.2
	_smoke_particles.direction = Vector2(0.0, -1.0)
	_smoke_particles.spread = 15.0
	_smoke_particles.gravity = Vector2(0.0, -10.0)
	_smoke_particles.initial_velocity_min = 8.0
	_smoke_particles.initial_velocity_max = 16.0
	_smoke_particles.scale_amount_min = 0.8
	_smoke_particles.scale_amount_max = 1.8
	_smoke_particles.color = Color(0.7, 0.7, 0.7, 0.5)
	_smoke_particles.position = Vector2(0.0, -8.0)
	add_child(_smoke_particles)

func _setup_aura() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.45, 0.1, 0.5))
	grad.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura_sprite = Sprite2D.new()
	_aura_sprite.texture = tex
	_aura_sprite.material = mat
	_aura_sprite.scale = Vector2(1.5, 1.5)
	_aura_sprite.visible = false
	add_child(_aura_sprite)

func _process(delta: float) -> void:
	var had_fuel := _fuel_remaining > 0.0
	if _fuel_remaining > 0.0:
		_fuel_remaining = maxf(0.0, _fuel_remaining - delta)
		if had_fuel and _fuel_remaining <= 0.0:
			_ember_remaining = EMBER_DURATION
	elif _ember_remaining > 0.0:
		_ember_remaining = maxf(0.0, _ember_remaining - delta)

	if _aura_sprite != null and _aura_sprite.visible:
		_aura_time += delta * 2.0
		_aura_sprite.scale = Vector2.ONE * (1.5 + 0.15 * sin(_aura_time))

	_refresh_visual_state()
	_refresh_progress_bar()

func _exit_tree() -> void:
	TemperatureHandler.unregister_source(self)
	on_destroy_signal.emit()

func setup(index: Vector2i, stove_data) -> void:
	room_index = index
	data = stove_data
	global_position = Building.global_position_from_room_index(index) + VISUAL_OFFSET

func set_outline(state: bool) -> void:
	_hovered = state
	_apply_outline()

func set_selected(state: bool) -> void:
	_selected = state
	_apply_outline()

func _apply_outline() -> void:
	if _sprite.material is not ShaderMaterial:
		return
	var outline_color: Color
	if _hovered and NPCWorker.picked_up_npc != null:
		outline_color = Color.GREEN
	elif _hovered or _selected:
		outline_color = Color.WHITE
	else:
		outline_color = Color.BLACK
	(_sprite.material as ShaderMaterial).set_shader_parameter("outline_color", outline_color)

func refuel() -> void:
	_fuel_remaining = MAX_FUEL_DURATION
	_ember_remaining = 0.0
	_refresh_visual_state()
	_refresh_progress_bar()

func needs_refuel() -> bool:
	return _fuel_remaining <= MAX_FUEL_DURATION * REFUEL_THRESHOLD_RATIO

func is_low_fuel() -> bool:
	return _fuel_remaining <= MAX_FUEL_DURATION * LOW_FUEL_VISIBILITY_RATIO

func is_heating() -> bool:
	return _fuel_remaining > 0.0 or _ember_remaining > 0.0

func get_fuel_ratio() -> float:
	return clampf(_fuel_remaining / MAX_FUEL_DURATION, 0.0, 1.0)

func get_fuel_seconds_remaining() -> float:
	return _fuel_remaining

func get_ember_seconds_remaining() -> float:
	return _ember_remaining

func get_backing_room() -> RoomBase:
	return Building.get_room_from_index(room_index) as RoomBase

func get_floor_position() -> Vector2:
	return Building.global_position_from_room_index(room_index)

func get_selection_title() -> String:
	return data.room_name if data != null and data.room_name != "" else "Stove"

func get_selection_description() -> String:
	return data.room_desc if data != null and data.room_desc != "" else "Keeps nearby rooms warm while fueled with wood."

func get_temperature_range() -> float:
	return HEAT_RANGE

func get_temperature_strength() -> float:
	if _fuel_remaining > 0.0:
		return 1.0
	if _ember_remaining > 0.0:
		return 0.25 * (_ember_remaining / EMBER_DURATION)
	return 0.0

func get_world_rect() -> Rect2:
	if _sprite.texture == null:
		return Rect2(global_position + Vector2(-14.0, -22.0), Vector2(28.0, 44.0))
	var size := _sprite.texture.get_size()
	return Rect2(global_position - size * 0.5, size)

func remove_self() -> void:
	Building.infrastructure.remove_at(room_index, BuildingInfrastructure.STOVE_LAYER)

func _refresh_visual_state() -> void:
	if _fuel_remaining > 0.0:
		_sprite.texture = _stove_on_texture
		_sprite.modulate = Color.WHITE
	elif _ember_remaining > 0.0:
		_sprite.texture = _stove_off_texure
		_sprite.modulate = EMBER_MODULATE
	else:
		_sprite.texture = _stove_off_texure
		_sprite.modulate = INACTIVE_MODULATE

	var heating := is_heating()
	if _warmth_light != null:
		_warmth_light.enabled = heating
	if _smoke_particles != null:
		_smoke_particles.emitting = _fuel_remaining > 0.0
	if _aura_sprite != null:
		_aura_sprite.visible = heating

func _refresh_progress_bar() -> void:
	_progress_bar.max_value = 100.0
	_progress_bar.value = get_fuel_ratio() * 100.0
	_progress_bar.visible = is_low_fuel() or not is_heating()
