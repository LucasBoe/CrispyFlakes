extends RoomBase
class_name RoomStove

const MAX_FUEL_DURATION := 60.0
const EMBER_DURATION := 8.0
const REFUEL_THRESHOLD_RATIO := 0.2
const LOW_FUEL_VISIBILITY_RATIO := 0.25
const REFUEL_DURATION := 2.5
const FIRE_START_CHANCE_PER_SECOND := 0.001
const HEAT_RANGE := 96.0
const EMBER_MODULATE := Color(0.85, 0.68, 0.52, 1.0)
const INACTIVE_MODULATE := Color(0.8, 0.8, 0.8, 1.0)
const AURA_TEXTURE := preload("res://assets/sprites/sun.png")
const AURA_POSITION := Vector2(24.0, -14.0)
const AURA_TINT := Color(1.0, 0.74, 0.38, 1.0)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _progress_bar: TextureProgressBar = $ProgressBar
@onready var _smoke_particles: GPUParticles2D = $SmokeParticles

const _STOVE_ON_TEXTURE = preload("res://assets/sprites/stove.png")
const _STOVE_OFF_TEXTURE = preload("res://assets/sprites/stove_off.png")

var _fuel_remaining := 0.0
var _ember_remaining := 0.0
var _overlay_light_registered := false

func _ready() -> void:
	_refresh_visual_state()
	_refresh_progress_bar()
	TemperatureHandler.register_source(self)
	call_deferred("_sync_overlay_light")

func _process(delta: float) -> void:
	_before_heat_update(delta)
	var had_fuel := _fuel_remaining > 0.0
	if _fuel_remaining > 0.0:
		_fuel_remaining = maxf(0.0, _fuel_remaining - delta * _get_fuel_burn_multiplier())
		if _should_start_fire(delta):
			FireHandler.start_fire(self)
		if had_fuel and _fuel_remaining <= 0.0:
			_ember_remaining = EMBER_DURATION
	elif _ember_remaining > 0.0:
		_ember_remaining = maxf(0.0, _ember_remaining - delta * _get_ember_burn_multiplier())

	_refresh_visual_state()
	_refresh_progress_bar()

func _exit_tree() -> void:
	RoomTemperatureOverlayHandler.unregister_light_input(self)
	TemperatureHandler.unregister_source(self)

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.STOVE_KEEPER

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

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

func get_floor_position() -> Vector2:
	# The room node's origin is the tile's left floor edge. Returning that puts
	# stove keepers on the room-edge seam in basement rooms instead of a proper
	# standing position, which can leave them visually tucked into the wall.
	return get_center_floor_position()

func get_temperature_range() -> float:
	return HEAT_RANGE

func get_temperature_strength() -> float:
	if _fuel_remaining > 0.0:
		return 1.0
	if _ember_remaining > 0.0:
		return 0.25 * (_ember_remaining / EMBER_DURATION)
	return 0.0

func _should_start_fire(delta: float) -> bool:
	return not FireHandler.is_room_on_fire(self) and randf() < FIRE_START_CHANCE_PER_SECOND * delta

func _before_heat_update(_delta: float) -> void:
	return

func _get_fuel_burn_multiplier() -> float:
	return 1.0

func _get_ember_burn_multiplier() -> float:
	return 1.0

func _get_active_texture() -> Texture2D:
	return _STOVE_ON_TEXTURE

func _get_inactive_texture() -> Texture2D:
	return _STOVE_OFF_TEXTURE

func _refresh_visual_state() -> void:
	if _fuel_remaining > 0.0:
		_sprite.texture = _get_active_texture()
		_sprite.modulate = Color.WHITE
	elif _ember_remaining > 0.0:
		_sprite.texture = _get_inactive_texture()
		_sprite.modulate = EMBER_MODULATE
	else:
		_sprite.texture = _get_inactive_texture()
		_sprite.modulate = INACTIVE_MODULATE

	var heating := is_heating()
	if _smoke_particles != null:
		_smoke_particles.emitting = _fuel_remaining > 0.0
	_sync_overlay_light()


func _sync_overlay_light() -> void:
	var should_register := is_heating()
	if should_register == _overlay_light_registered:
		return

	_overlay_light_registered = should_register
	if should_register:
		RoomTemperatureOverlayHandler.register_light_input(
			self,
			self,
			AURA_TEXTURE,
			global_position + AURA_POSITION,
			AURA_TINT
		)
	else:
		RoomTemperatureOverlayHandler.unregister_light_input(self)

func _refresh_progress_bar() -> void:
	_progress_bar.max_value = 100.0
	_progress_bar.value = get_fuel_ratio() * 100.0
	_progress_bar.visible = is_low_fuel() or not is_heating()
