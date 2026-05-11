extends Node

const PanicBehaviourScript = preload("res://scripts/npc/behaviours/panic_behaviour.gd")
const ExtinguishFireBehaviourScript = preload("res://scripts/npc/behaviours/extinguish_fire_behaviour.gd")
const FireIncidentScript = preload("res://scripts/fire.gd")
const FIRE_LIGHT_OVERLAY_SCENE = preload("res://scenes/fire_light_overlay.tscn")
const FIRE_FLAME_PARTICLES_SCENE = preload("res://scenes/fire_flame_particles.tscn")
const FIRE_SPARK_PARTICLES_SCENE = preload("res://scenes/fire_spark_particles.tscn")
const FIRE_REGULAR_SMOKE_SCENE = preload("res://scenes/fire_regular_smoke_particles.tscn")
const FIRE_EXTINGUISH_SMOKE_SCENE = preload("res://scenes/fire_extinguish_smoke_particles.tscn")

const RESPONSE_RANGE_X := 96.0
const RESPONSE_RANGE_Y := 16.0
const SPREAD_CHANCE := 0.25
const FIRE_COLOR := Color(1.0, 0.08, 0.02, 1.0)
const FIRE_PULSE_COLOR := Color(1.0, 0.46, 0.02, 1.0)
const EXTINGUISH_BAR_COLOR := Color(0.55, 0.55, 0.55, 1.0)
const PROPAGATION_BAR_COLOR := Color(1.0, 0.08, 0.02, 1.0)
const FIRE_BAR_SIZE := Vector2(30.0, 2.0)
const PROPAGATION_BAR_SIZE := Vector2(22.0, 2.0)
const REGULAR_SMOKE_MIN_INTERVAL := 0.35
const REGULAR_SMOKE_MAX_INTERVAL := 1.0

var active_fires: Array = []
var _next_fire_debug_id := 1

func _ready() -> void:
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)
	Console.add_command("random_fire", console_start_random_fire, 0, 0, "Starts a fire in a random indoor room.")
	Console.add_command("fire_random", console_start_random_fire, 0, 0, "Starts a fire in a random indoor room.")

func _process(delta: float) -> void:
	for fire in active_fires.duplicate():
		if not active_fires.has(fire):
			continue
		if not fire.is_active():
			end_fire(fire)
			continue

		var propagation_delta: float = delta * fire.get_extinguish_ratio()
		fire.age += propagation_delta
		fire.spread_roll_elapsed += propagation_delta
		_update_highlight(fire)
		_try_panic_near_fire(fire)
		_try_auto_respond_near_fire(fire)
		_try_spawn_regular_smoke(fire, delta)
		_try_spread(fire)

func start_fire(room: RoomBase):
	if room == null or not is_instance_valid(room) or room.is_outside_room:
		return null

	var existing = get_fire_for_room(room)
	if existing != null:
		return existing

	var fire = FireIncidentScript.new(room)
	fire.debug_id = _next_fire_debug_id
	_next_fire_debug_id += 1
	fire.next_smoke_time = randf_range(REGULAR_SMOKE_MIN_INTERVAL, REGULAR_SMOKE_MAX_INTERVAL)
	fire.highlight = RoomHighlighter.request_rect(room, FIRE_COLOR, 2, RoomHighlighter.Priority.FIRE)
	_create_fire_bars(fire)
	_create_flame_particles(fire)
	active_fires.append(fire)
	print("[FireHandler] start fire %s" % fire.debug_label())
	return fire

func start_fire_at_global_position(global_pos: Vector2):
	var room := Building.query.room_at_floor_position(global_pos) as RoomBase
	if room == null:
		room = Building.query.closest_on_current_floor(RoomBase, global_pos) as RoomBase
	return start_fire(room)

func start_fire_in_hovered_room():
	return start_fire(HoverHandler.currently_hovered as RoomBase)

func console_start_random_fire() -> void:
	var room := _pick_random_fire_room()
	if room == null:
		Console.print_error("No valid indoor room available for a random fire.")
		return

	var fire = start_fire(room)
	if fire == null:
		Console.print_error("Failed to start random fire.")
		return

	Console.print_line("Started fire in %s at (%d, %d)." % [room.data.room_name, room.x, room.y])

func end_fire(fire) -> void:
	if fire == null or not active_fires.has(fire):
		return
	print("[FireHandler] end fire %s" % fire.debug_label())
	_dispose_fire_bars(fire)
	_dispose_light_overlay(fire)
	_dispose_flame_particles(fire)
	_dispose_spark_particles(fire)
	RoomHighlighter.dispose(fire.highlight)
	fire.highlight = null
	active_fires.erase(fire)

func apply_liquid(fire, amount: float) -> void:
	if fire == null or not active_fires.has(fire):
		return
	spawn_extinguish_smoke(fire)
	fire.apply_liquid(amount)
	if fire.health <= 0.0:
		end_fire(fire)

func spawn_extinguish_smoke(fire) -> void:
	if fire == null or not is_instance_valid(fire.room):
		return

	_spawn_smoke_at(fire.room, fire.room.get_center_floor_position() + Vector2(0.0, -14.0))

func _try_spawn_regular_smoke(fire, delta: float) -> void:
	if fire == null or not is_instance_valid(fire.room):
		return
	fire.smoke_elapsed += delta
	if fire.smoke_elapsed < fire.next_smoke_time:
		return

	fire.smoke_elapsed = 0.0
	fire.next_smoke_time = randf_range(REGULAR_SMOKE_MIN_INTERVAL, REGULAR_SMOKE_MAX_INTERVAL)
	var width := float(fire.room.data.width * RoomHighlighter.TILE_PX)
	var smoke_pos: Vector2 = fire.room.global_position + Vector2(
		randf_range(6.0, maxf(6.0, width - 6.0)),
		-randf_range(8.0, 22.0)
	)
	_spawn_regular_smoke_at(fire.room, smoke_pos)

func _spawn_smoke_at(parent: Node, global_pos: Vector2) -> void:
	var smoke := FIRE_EXTINGUISH_SMOKE_SCENE.instantiate() as GPUParticles2D
	parent.add_child(smoke)
	smoke.global_position = global_pos
	smoke.finished.connect(smoke.queue_free)
	smoke.restart()
	smoke.emitting = true

func _spawn_regular_smoke_at(parent: Node, global_pos: Vector2) -> void:
	var smoke := FIRE_REGULAR_SMOKE_SCENE.instantiate() as GPUParticles2D
	parent.add_child(smoke)
	smoke.global_position = global_pos
	smoke.finished.connect(smoke.queue_free)
	smoke.restart()
	smoke.emitting = true

func get_fire_for_room(room: RoomBase):
	if room == null:
		return null
	for fire in active_fires:
		if fire.room == room:
			return fire
	return null

func is_active_fire(fire) -> bool:
	return fire != null and active_fires.has(fire) and fire.is_active()

func is_room_on_fire(room: RoomBase) -> bool:
	return get_fire_for_room(room) != null

func is_fire_near_room(room: RoomBase) -> bool:
	if not is_instance_valid(room):
		return false
	for fire in active_fires:
		if not fire.is_active():
			continue
		if fire.room == room:
			return true
		if is_within_fire_response_range(fire.get_position(), room.get_center_floor_position()):
			return true
	return false

func is_within_fire_response_range(a: Vector2, b: Vector2) -> bool:
	var diff := b - a
	return abs(diff.x) < RESPONSE_RANGE_X and abs(diff.y) < RESPONSE_RANGE_Y

func _try_auto_respond_near_fire(fire) -> void:
	if Global.NPCSpawner == null:
		return

	for worker: NPCWorker in Global.NPCSpawner.workers:
		if not _can_worker_respond(worker, fire):
			continue

		var response_data := BehaviourSaveData.new(ExtinguishFireBehaviourScript)
		response_data.extra["fire"] = fire
		response_data.extra["threat_room"] = fire.room
		response_data.extra["threat_position"] = fire.get_position()
		worker.Behaviour.set_behaviour(ExtinguishFireBehaviourScript, response_data)

func _can_worker_respond(worker: NPCWorker, fire) -> bool:
	if not is_instance_valid(worker) or worker.Behaviour == null:
		return false
	if NPCWorker.picked_up_npc == worker:
		return false
	if not is_within_fire_response_range(fire.get_position(), worker.global_position):
		return false

	var current = worker.Behaviour.behaviour_instance
	if current != null and current.get_script() == ExtinguishFireBehaviourScript:
		return false
	if current is FightBehaviour or current is KnockedOutBehaviour or current is ArrestedBehaviour or current is FollowSheriffBehaviour or current is LeaveOnHorseBehaviour:
		return false
	return true

func _try_panic_near_fire(fire) -> void:
	if Global.NPCSpawner == null:
		return

	for guest: NPCGuest in Global.NPCSpawner.guests:
		_try_panic_npc(guest, fire)

func _try_panic_npc(npc: NPC, fire) -> bool:
	if not _can_panic_from_fire(npc, fire):
		return false

	var panic_data := BehaviourSaveData.new(PanicBehaviourScript)
	panic_data.extra["fire"] = fire
	panic_data.extra["threat_room"] = fire.room
	panic_data.extra["threat_position"] = fire.get_position()
	npc.Behaviour.set_behaviour(PanicBehaviourScript, panic_data)
	return true

func _can_panic_from_fire(npc: NPC, fire) -> bool:
	if not is_instance_valid(npc) or npc.Behaviour == null:
		return false
	if not is_within_fire_response_range(fire.get_position(), npc.global_position):
		return false

	var current = npc.Behaviour.behaviour_instance
	if current != null and current.get_script() == PanicBehaviourScript:
		return false
	if current is KnockedOutBehaviour or current is ArrestedBehaviour or current is FollowSheriffBehaviour or current is LeaveOnHorseBehaviour:
		return false
	return true

func _try_spread(fire) -> void:
	if fire.age < FireIncidentScript.SPREAD_DELAY:
		return
	if fire.spread_roll_elapsed < FireIncidentScript.SPREAD_ROLL_INTERVAL:
		return
	fire.spread_roll_elapsed = 0.0

	if randf() >= SPREAD_CHANCE:
		return

	var target := _pick_spread_room(fire.room)
	if target != null:
		start_fire(target)

func _pick_spread_room(room: RoomBase) -> RoomBase:
	var candidates := _get_adjacent_rooms(room)
	if candidates.is_empty():
		return null
	return candidates.pick_random()

func _pick_random_fire_room() -> RoomBase:
	var candidates: Array[RoomBase] = []
	var seen := {}
	for floor_rooms: Dictionary in Building.floors.values():
		for room: RoomBase in floor_rooms.values():
			if room == null or room.is_outside_room or is_room_on_fire(room):
				continue
			var room_id := room.get_instance_id()
			if seen.has(room_id):
				continue
			seen[room_id] = true
			candidates.append(room)

	if candidates.is_empty():
		return null
	return candidates.pick_random()

func _get_adjacent_rooms(room: RoomBase) -> Array[RoomBase]:
	var candidates: Array[RoomBase] = []
	var seen := {}
	if room == null or room.data == null:
		return candidates

	for col in room.data.width:
		for row in room.data.height:
			var index := Vector2i(room.x + col, room.y + row)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var candidate := Building.get_room_from_index(index + direction) as RoomBase
				if candidate == null or candidate == room or candidate.is_outside_room:
					continue
				if is_room_on_fire(candidate):
					continue
				var candidate_id := candidate.get_instance_id()
				if seen.has(candidate_id):
					continue
				seen[candidate_id] = true
				candidates.append(candidate)
	return candidates

func _update_highlight(fire) -> void:
	if not is_instance_valid(fire.highlight):
		return
	var t := (sin(Global.time_now * 8.0) + 1.0) * 0.5
	fire.highlight.modulate = FIRE_COLOR.lerp(FIRE_PULSE_COLOR, t)
	_update_fire_bars(fire)
	_update_light_overlay(fire)
	_update_flame_particles(fire)
	_update_spark_particles(fire)

func _create_fire_bars(fire) -> void:
	if fire == null or not is_instance_valid(fire.room):
		return
	var room_width := float(fire.room.data.width * RoomHighlighter.TILE_PX)
	var extinguish_x_offset := room_width * 0.5 - FIRE_BAR_SIZE.x * 0.5
	var propagation_x_offset := room_width * 0.5 - PROPAGATION_BAR_SIZE.x * 0.5
	fire.extinguish_bar = UiNotifications.create_world_progress_bar(
		fire.room,
		Vector2(extinguish_x_offset, -50.0),
		EXTINGUISH_BAR_COLOR,
		FIRE_BAR_SIZE
	)
	fire.propagation_bar = UiNotifications.create_world_progress_bar(
		fire.room,
		Vector2(propagation_x_offset, -47.0),
		PROPAGATION_BAR_COLOR,
		PROPAGATION_BAR_SIZE
	)
	_update_fire_bars(fire)

func _update_fire_bars(fire) -> void:
	if fire == null:
		return
	UiNotifications.update_progress_bar(fire.extinguish_bar, fire.get_extinguish_ratio())
	UiNotifications.update_progress_bar(fire.propagation_bar, fire.get_propagation_progress_ratio())

func _dispose_fire_bars(fire) -> void:
	if fire == null:
		return
	UiNotifications.try_kill(fire.extinguish_bar)
	UiNotifications.try_kill(fire.propagation_bar)
	fire.extinguish_bar = null
	fire.propagation_bar = null

func _create_light_overlay(fire) -> void:
	if fire == null or not is_instance_valid(fire.room):
		return
	var overlay = FIRE_LIGHT_OVERLAY_SCENE.instantiate()
	fire.room.add_child(overlay)
	overlay.global_position = fire.room.get_center_floor_position()
	fire.light_overlay = overlay
	_update_light_overlay(fire)

func _update_light_overlay(fire) -> void:
	if fire == null or not is_instance_valid(fire.light_overlay):
		return
	var fire_size: float = fire.get_fire_growth_ratio() * fire.get_extinguish_ratio()
	var pulse: float = lerpf(0.85, 1.0, (sin(Global.time_now * 10.0) + 1.0) * 0.5)
	fire.light_overlay.modulate = Color(1.0, 1.0, 1.0, lerpf(0.45, 1.0, fire_size) * pulse)

func _dispose_light_overlay(fire) -> void:
	if fire == null:
		return
	if is_instance_valid(fire.light_overlay):
		fire.light_overlay.queue_free()
	fire.light_overlay = null

func _create_flame_particles(fire) -> void:
	if fire == null or not is_instance_valid(fire.room):
		return
	_create_light_overlay(fire)
	var particles = FIRE_FLAME_PARTICLES_SCENE.instantiate()
	fire.room.add_child(particles)
	particles.global_position = fire.room.get_center_floor_position()
	fire.flame_particles = particles
	_create_spark_particles(fire)
	_update_flame_particles(fire)

func _update_flame_particles(fire) -> void:
	if fire == null or not is_instance_valid(fire.flame_particles):
		return
	fire.flame_particles.set_fire_state(fire.get_fire_growth_ratio(), fire.get_extinguish_ratio())

func _dispose_flame_particles(fire) -> void:
	if fire == null:
		return
	if is_instance_valid(fire.flame_particles):
		fire.flame_particles.queue_free()
	fire.flame_particles = null

func _create_spark_particles(fire) -> void:
	if fire == null or not is_instance_valid(fire.room):
		return
	var particles = FIRE_SPARK_PARTICLES_SCENE.instantiate()
	fire.room.add_child(particles)
	particles.global_position = fire.room.get_center_floor_position()
	fire.spark_particles = particles
	_update_spark_particles(fire)

func _update_spark_particles(fire) -> void:
	if fire == null or not is_instance_valid(fire.spark_particles):
		return
	fire.spark_particles.set_fire_state(fire.get_fire_growth_ratio(), fire.get_extinguish_ratio())

func _dispose_spark_particles(fire) -> void:
	if fire == null:
		return
	if is_instance_valid(fire.spark_particles):
		fire.spark_particles.queue_free()
	fire.spark_particles = null

func _on_room_deleted(room: RoomBase) -> void:
	var fire = get_fire_for_room(room)
	if fire != null:
		end_fire(fire)
