extends Node

const FLOOR_DIRT_SCENE := preload("res://scenes/floor_dirt_mess.tscn")
const STINK_PARTICLES_SCENE := preload("res://scenes/floor_dirt_stink_particles.tscn")
const FLY_PARTICLES_SCENE := preload("res://scenes/floor_dirt_fly_particles.tscn")
const DIRT_MERGE_RADIUS := 10.0
const DEBUG_NOTIFICATION_DURATION := 0.15
const STINK_BASE_AMOUNT := 12
const FLY_BASE_AMOUNT := 14
const MAX_REPRESENTED_DIRT := 32
const AMOUNT_RATIO_SCALE := 0.15
const AMOUNT_RATIO_REFRESH_INTERVAL := 10.0

var dirt_instances: Array[Sprite2D] = []
var _stink_particles: GPUParticles2D
var _fly_particles: GPUParticles2D
var _stink_index := -1
var _fly_index := -1
var _amount_ratio_refresh_elapsed := 10.0

func _ready() -> void:
	_stink_particles = STINK_PARTICLES_SCENE.instantiate() as GPUParticles2D
	_fly_particles = FLY_PARTICLES_SCENE.instantiate() as GPUParticles2D
	_stink_particles.amount = STINK_BASE_AMOUNT * MAX_REPRESENTED_DIRT
	_fly_particles.amount = FLY_BASE_AMOUNT * MAX_REPRESENTED_DIRT
	add_child(_stink_particles)
	add_child(_fly_particles)
	_effects_loop()

func _effects_loop() -> void:
	while true:
		await get_tree().process_frame
		_amount_ratio_refresh_elapsed += get_process_delta_time()
		_prune_invalid_dirt()
		if dirt_instances.is_empty():
			_stink_particles.visible = false
			_stink_particles.emitting = false
			_fly_particles.visible = false
			_fly_particles.emitting = false
			continue

		if _amount_ratio_refresh_elapsed >= AMOUNT_RATIO_REFRESH_INTERVAL:
			_amount_ratio_refresh_elapsed = 0.0
			var amount_ratio := minf((float(dirt_instances.size()) / float(MAX_REPRESENTED_DIRT)) * AMOUNT_RATIO_SCALE, 1.0)
			_stink_particles.amount_ratio = amount_ratio
			_fly_particles.amount_ratio = amount_ratio

		_stink_index = posmod(_stink_index + 1, dirt_instances.size())
		_fly_index = posmod(_fly_index + 1, dirt_instances.size())

		var stink_target := dirt_instances[_stink_index] as FloorDirtMess
		var fly_target := dirt_instances[_fly_index] as FloorDirtMess

		_stink_particles.global_position = stink_target.get_stink_anchor_global_position()
		_stink_particles.visible = true
		_stink_particles.emitting = true
		_debug_teleport("S %d,%d" % [roundi(_stink_particles.global_position.x), roundi(_stink_particles.global_position.y)], _stink_particles.global_position, Color.YELLOW)

		_fly_particles.global_position = fly_target.get_fly_anchor_global_position()
		_fly_particles.visible = true
		_fly_particles.emitting = true
		_debug_teleport("F %d,%d" % [roundi(_fly_particles.global_position.x), roundi(_fly_particles.global_position.y)], _fly_particles.global_position, Color.CYAN)

func create_dirt_at(position_in_global_space: Vector2) -> void:
	var closest_existing := get_closest_to(position_in_global_space)
	if closest_existing != null and closest_existing.global_position.distance_squared_to(position_in_global_space) < DIRT_MERGE_RADIUS * DIRT_MERGE_RADIUS:
		return

	var new_dirt_instance := FLOOR_DIRT_SCENE.instantiate() as FloorDirtMess
	new_dirt_instance.global_position = position_in_global_space - Vector2(0, 1)
	add_child(new_dirt_instance)
	dirt_instances.append(new_dirt_instance)

func get_closest_to(global_pos: Vector2) -> Sprite2D:
	var closest: Sprite2D = null
	var best_dist := INF

	for i in range(dirt_instances.size() - 1, -1, -1):
		var dirt := dirt_instances[i]
		if not is_instance_valid(dirt):
			dirt_instances.remove_at(i)
			continue

		var d := dirt.global_position.distance_squared_to(global_pos)
		if d < best_dist:
			best_dist = d
			closest = dirt

	return closest

func get_all_in_range(global_pos: Vector2, range: float) -> Array[Sprite2D]:
	var dirt_in_range: Array[Sprite2D] = []
	var range_squared := range * range

	for i in range(dirt_instances.size() - 1, -1, -1):
		var dirt := dirt_instances[i] as Sprite2D
		if not is_instance_valid(dirt):
			dirt_instances.remove_at(i)
			continue

		if dirt.global_position.distance_squared_to(global_pos) <= range_squared:
			dirt_in_range.append(dirt)

	return dirt_in_range

func clean_dirt(dirt: Sprite2D) -> void:
	if dirt_instances.has(dirt):
		dirt_instances.erase(dirt)
	if is_instance_valid(dirt):
		dirt.queue_free()

func _prune_invalid_dirt() -> void:
	for i in range(dirt_instances.size() - 1, -1, -1):
		if not is_instance_valid(dirt_instances[i]):
			dirt_instances.remove_at(i)

func _debug_teleport(text: String, world_pos: Vector2, color: Color) -> void:
	UiNotifications.create_notification_static(text, world_pos + Vector2(-8, -18), null, color, DEBUG_NOTIFICATION_DURATION)
