extends Node2D

@onready var mouse_click_down = $MouseClickDown
@onready var mouse_click_up = $MouseClickUp
@onready var construction_placed = $ConstructionPlaced
@onready var coin = $Coin
@onready var treasure = $Treasure

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
const _TALK_STREAMS : Array[AudioStream] = [
	preload("res://assets/sounds/sounds/talk1.wav"),
	preload("res://assets/sounds/sounds/talk2.wav"),
	preload("res://assets/sounds/sounds/talk3.wav"),
	preload("res://assets/sounds/sounds/talk4.wav"),
	preload("res://assets/sounds/sounds/talk5.wav"),
	preload("res://assets/sounds/sounds/talk6.wav"),
]

func play_talk(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _TALK_STREAMS.pick_random()
	player.global_position = world_position
	player.pitch_scale = 0.8 + randf() * 0.4
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_piano_loop(world_position: Vector2) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.stream = _PIANO_LOOP_STREAM
	player.global_position = world_position
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.play)
	player.play()
	return player

func play_brewery_loop(world_position: Vector2) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.stream = _BREWERY_LOOP_STREAM
	player.global_position = world_position
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.play)
	player.play()
	return player

func play_punch(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _PUNCH_STREAM
	player.global_position = world_position
	player.pitch_scale = 0.7 + randf() * 0.6
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_serve_drink(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _SERVE_DRINK_STREAM
	player.global_position = world_position
	player.pitch_scale = 0.9 + randf() * 0.2
	player.volume_db = -6.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_water(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _WATER_STREAM
	player.global_position = world_position
	player.pitch_scale = 0.9 + randf() * 0.2
	player.volume_db = -6.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_use_well(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _USE_WELL_STREAM
	player.global_position = world_position
	player.pitch_scale = 0.9 + randf() * 0.2
	player.volume_db = -10.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_broom(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _BROOM_STREAM
	player.global_position = world_position
	player.pitch_scale = 0.9 + randf() * 0.2
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_outhouse_door(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _OUTHOUSE_DOOR_STREAM
	player.global_position = world_position
	player.pitch_scale = 0.9 + randf() * 0.2
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_piss(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _PISS_STREAM
	player.global_position = world_position
	player.pitch_scale = 0.9 + randf() * 0.2
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_puke(world_position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = _PUKE_STREAMS.pick_random()
	player.global_position = world_position
	player.pitch_scale = 0.8 + randf() * 0.4
	player.volume_db = -12.0
	player.max_distance = 300.0
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
