extends Node2D

const _DEFAULT_BUS := &"SFX"
const _DEFAULT_MAX_DISTANCE := 300.0

@onready var _mouse_click_down: CustomAudioStreamPlayer = $MouseClickDown
@onready var _mouse_click_up: CustomAudioStreamPlayer = $MouseClickUp
@onready var _construction_placed: CustomAudioStreamPlayer = $ConstructionPlaced
@onready var _coin: CustomAudioStreamPlayer = $Coin
@onready var _treasure: CustomAudioStreamPlayer = $Treasure

const _BREWERY_LOOP_STREAM : AudioStream = preload("res://assets/sounds/sounds/brewery_active_loop.wav")
const _PIANO_LOOP_STREAM : AudioStream = preload("res://assets/sounds/sounds/piano_loop.wav")
const _PUNCH_STREAM : AudioStream = preload("res://assets/sounds/sounds/punch.wav")
const _SERVE_DRINK_STREAM : AudioStream = preload("res://assets/sounds/sounds/serve_drink.wav")
const _WATER_STREAM : AudioStream = preload("res://assets/sounds/sounds/water.wav")
const _USE_WELL_STREAM : AudioStream = preload("res://assets/sounds/sounds/use_well.wav")
const _BROOM_STREAM : AudioStream = preload("res://assets/sounds/sounds/broom.wav")
const _OUTHOUSE_DOOR_STREAM : AudioStream = preload("res://assets/sounds/sounds/outhouse_door.wav")
const _PISS_STREAM : AudioStream = preload("res://assets/sounds/sounds/piss.wav")
const _PUKE_STREAMS : Array[AudioStream] = [
	preload("res://assets/sounds/sounds/puke1.wav"),
	preload("res://assets/sounds/sounds/puke2.wav"),
	preload("res://assets/sounds/sounds/puke3.wav"),
]
const _HORSE_STREAMS : Array[AudioStream] = [
	preload("res://assets/sounds/sounds/horse1.wav"),
	preload("res://assets/sounds/sounds/horse2.wav"),
	preload("res://assets/sounds/sounds/horse3.wav"),
]
const _TALK_STREAMS : Array[AudioStream] = [
	preload("res://assets/sounds/sounds/talk1.wav"),
	preload("res://assets/sounds/sounds/talk2.wav"),
	preload("res://assets/sounds/sounds/talk3.wav"),
	preload("res://assets/sounds/sounds/talk4.wav"),
	preload("res://assets/sounds/sounds/talk5.wav"),
	preload("res://assets/sounds/sounds/talk6.wav"),
]

func play_talk(world_position: Vector2) -> void:
	_play_2d(_TALK_STREAMS.pick_random(), world_position, -12.0, 0.8, 1.2)

func play_piano_loop(world_position: Vector2) -> AudioStreamPlayer2D:
	return _play_2d(_PIANO_LOOP_STREAM, world_position, -12.0, 1.0, 1.0, true)

func play_brewery_loop(world_position: Vector2) -> AudioStreamPlayer2D:
	return _play_2d(_BREWERY_LOOP_STREAM, world_position, -12.0, 1.0, 1.0, true)

func play_punch(world_position: Vector2) -> void:
	_play_2d(_PUNCH_STREAM, world_position, -12.0, 0.7, 1.3)

func play_serve_drink(world_position: Vector2) -> void:
	_play_2d(_SERVE_DRINK_STREAM, world_position, -6.0, 0.9, 1.1)

func play_water(world_position: Vector2) -> void:
	_play_2d(_WATER_STREAM, world_position, -6.0, 0.9, 1.1)

func play_use_well(world_position: Vector2) -> void:
	_play_2d(_USE_WELL_STREAM, world_position, -10.0, 0.9, 1.1)

func play_broom(world_position: Vector2) -> void:
	_play_2d(_BROOM_STREAM, world_position, -12.0, 0.9, 1.1)

func play_outhouse_door(world_position: Vector2) -> void:
	_play_2d(_OUTHOUSE_DOOR_STREAM, world_position, -12.0, 0.9, 1.1)

func play_piss(world_position: Vector2) -> void:
	_play_2d(_PISS_STREAM, world_position, -8.0, 0.9, 1.1)

func play_puke(world_position: Vector2) -> void:
	_play_2d(_PUKE_STREAMS.pick_random(), world_position, -10.0, 0.8, 1.2)

func play_horse(world_position: Vector2) -> void:
	_play_2d(_HORSE_STREAMS.pick_random(), world_position, -10.0, 0.9, 1.1)

func play_ui_click_down(_value = null) -> void:
	_mouse_click_down.play_random_pitch()

func play_ui_click_up(_value = null) -> void:
	_mouse_click_up.play_random_pitch()

func play_construction_placed() -> void:
	_construction_placed.play_random_pitch()

func play_coin() -> void:
	_coin.play_random_pitch()

func play_treasure() -> void:
	_treasure.play_random_pitch()

func _play_2d(
	stream: AudioStream,
	world_position: Vector2,
	volume_db: float,
	pitch_min: float,
	pitch_max: float,
	loop := false
) -> AudioStreamPlayer2D:
	var player := CustomAudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = world_position
	player.volume_db = volume_db
	player.max_distance = _DEFAULT_MAX_DISTANCE
	player.bus = _DEFAULT_BUS
	player.random_pitch_min = pitch_min
	player.random_pitch_max = pitch_max
	add_child(player)

	if loop:
		player.finished.connect(player.play)
		player.play()
	else:
		player.finished.connect(player.queue_free)
		player.play_random_pitch()

	return player
