class_name FireIncident

const MAX_HEALTH := 3.0
const SPREAD_DELAY := 30.0
const SPREAD_ROLL_INTERVAL := 5.0

var room: RoomBase
var age := 0.0
var health := MAX_HEALTH
var spread_roll_elapsed := 0.0
var extinguish_bar
var propagation_bar
var light_overlay
var flame_particles
var spark_particles
var loop_sound: AudioStreamPlayer2D
var smoke_elapsed := 0.0
var next_smoke_time := 0.0
var debug_id := -1

func _init(target_room: RoomBase) -> void:
	room = target_room

func is_active() -> bool:
	return health > 0.0 and is_instance_valid(room)

func apply_liquid(amount: float) -> void:
	health = maxf(0.0, health - amount)

func get_extinguish_ratio() -> float:
	return clampf(health / MAX_HEALTH, 0.0, 1.0)

func get_propagation_progress_ratio() -> float:
	if age < SPREAD_DELAY:
		return clampf(age / SPREAD_DELAY, 0.0, 1.0)
	return clampf(spread_roll_elapsed / SPREAD_ROLL_INTERVAL, 0.0, 1.0)

func get_fire_growth_ratio() -> float:
	return clampf(age / SPREAD_DELAY, 0.0, 1.0)

func get_position() -> Vector2:
	if is_instance_valid(room):
		return room.get_center_floor_position()
	return Vector2.INF

func debug_label() -> String:
	return "#%d room=%s health=%.2f age=%.1f" % [
		debug_id,
		room.name if is_instance_valid(room) else "<none>",
		health,
		age,
	]
