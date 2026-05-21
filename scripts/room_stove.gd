extends RoomBase
class_name RoomStove

const MAX_FUEL_DURATION := 60.0
const EMBER_DURATION := 8.0
const REFUEL_THRESHOLD_RATIO := 0.2
const LOW_FUEL_VISIBILITY_RATIO := 0.25
const REFUEL_DURATION := 2.5
const FIRE_START_CHANCE_PER_SECOND := 0.001
const HEAT_RANGE := 96.0
const HEAT_LIGHT_ENERGY := 0.85
const HEAT_RADIUS_FILL_COLOR := Color(1.0, 0.38, 0.08, 0.12)
const EMBER_MODULATE := Color(0.85, 0.68, 0.52, 1.0)
const INACTIVE_MODULATE := Color(0.8, 0.8, 0.8, 1.0)
const SPRITE_OFFSET := Vector2(8, -22)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _progress_bar: TextureProgressBar = $ProgressBar
@onready var _warmth_light: PointLight2D = $WarmthLight
@onready var _smoke_particles: GPUParticles2D = $SmokeParticles
@onready var _aura_sprite: Sprite2D = $AuraSprite

const _STOVE_ON_TEXTURE = preload("res://assets/sprites/stove.png")
const _STOVE_OFF_TEXTURE = preload("res://assets/sprites/stove_off.png")

var _fuel_remaining := 0.0
var _ember_remaining := 0.0
var _aura_time := 0.0

func _ready() -> void:
	_refresh_visual_state()
	_refresh_progress_bar()
	TemperatureHandler.register_source(self)

func _draw() -> void:
	if not is_heating():
		return
	var strength := clampf(get_temperature_strength(), 0.0, 1.0)
	var fill_color := HEAT_RADIUS_FILL_COLOR
	fill_color.a *= strength
	draw_circle(SPRITE_OFFSET, HEAT_RANGE, fill_color)

func _process(delta: float) -> void:
	var had_fuel := _fuel_remaining > 0.0
	if _fuel_remaining > 0.0:
		_fuel_remaining = maxf(0.0, _fuel_remaining - delta)
		if _should_start_fire(delta):
			FireHandler.start_fire(self)
		if had_fuel and _fuel_remaining <= 0.0:
			_ember_remaining = EMBER_DURATION
	elif _ember_remaining > 0.0:
		_ember_remaining = maxf(0.0, _ember_remaining - delta)

	_refresh_visual_state()
	_refresh_progress_bar()
	if is_heating():
		queue_redraw()

func _exit_tree() -> void:
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
	return global_position

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

func _refresh_visual_state() -> void:
	if _fuel_remaining > 0.0:
		_sprite.texture = _STOVE_ON_TEXTURE
		_sprite.modulate = Color.WHITE
	elif _ember_remaining > 0.0:
		_sprite.texture = _STOVE_OFF_TEXTURE
		_sprite.modulate = EMBER_MODULATE
	else:
		_sprite.texture = _STOVE_OFF_TEXTURE
		_sprite.modulate = INACTIVE_MODULATE

	var heating := is_heating()
	if _warmth_light != null:
		_warmth_light.enabled = heating
		_warmth_light.energy = HEAT_LIGHT_ENERGY * clampf(get_temperature_strength(), 0.0, 1.0)
	if _smoke_particles != null:
		_smoke_particles.emitting = _fuel_remaining > 0.0
	if _aura_sprite != null:
		_aura_sprite.visible = heating
	queue_redraw()

func _refresh_progress_bar() -> void:
	_progress_bar.max_value = 100.0
	_progress_bar.value = get_fuel_ratio() * 100.0
	_progress_bar.visible = is_low_fuel() or not is_heating()
