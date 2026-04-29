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

func _ready() -> void:
	if _sprite.material is ShaderMaterial:
		_sprite.material = (_sprite.material as ShaderMaterial).duplicate(true)
	_apply_outline()
	_refresh_visual_state()
	_refresh_progress_bar()
	TemperatureHandler.register_source(self)

func _process(delta: float) -> void:
	var had_fuel := _fuel_remaining > 0.0
	if _fuel_remaining > 0.0:
		_fuel_remaining = maxf(0.0, _fuel_remaining - delta)
		if had_fuel and _fuel_remaining <= 0.0:
			_ember_remaining = EMBER_DURATION
	elif _ember_remaining > 0.0:
		_ember_remaining = maxf(0.0, _ember_remaining - delta)

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
	var outline_color := Color.WHITE if _hovered or _selected else Color.BLACK
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

func _refresh_progress_bar() -> void:
	_progress_bar.max_value = 100.0
	_progress_bar.value = get_fuel_ratio() * 100.0
	_progress_bar.visible = is_low_fuel() or not is_heating()
