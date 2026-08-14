extends RoomBase
class_name RoomEntertainment

const DEFAULT_EFFECT_INTERVAL := 10.0
const DEFAULT_MOOD_BOOST := 0.08
const PERFORMANCE_RANGE := 2

var _guests_swaying_enabled := false
var _debug_last_worker_state := ""
var _debug_last_active_state = null
var _debug_last_particles_state = null
@onready var music_particles: GPUParticles2D = $MusicParticles

func init_room(_x: int, _y: int):
	associated_job = Enum.Jobs.ENTERTAINMENT
	super.init_room(_x, _y)
	_capture_performance_debug_state()

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func _on_module_bought(module) -> void:
	if not module.bought:
		return
	current_module = module

func get_performance_interval() -> float:
	if current_module and current_module.effect_interval > 0.0:
		return current_module.effect_interval
	return DEFAULT_EFFECT_INTERVAL

func get_mood_boost() -> float:
	if current_module and current_module.mood_boost > 0.0:
		return current_module.mood_boost
	return DEFAULT_MOOD_BOOST

func get_performance_name() -> String:
	if current_module != null and not current_module.module_name.is_empty():
		return current_module.module_name
	return "Act"

func has_active_performance() -> bool:
	return current_module != null and has_valid_worker()

func _process(_delta):
	var worker_state_before := _get_worker_debug_state()
	var performance_active := has_active_performance()
	var worker_state_after := _get_worker_debug_state()
	if AnimationModule.debug_performance_enabled and worker_state_before != worker_state_after:
		DebugLog.info("[Performance]", _get_performance_debug_label(), "worker_reconciled", worker_state_before, "->", worker_state_after)
	if performance_active and not _guests_swaying_enabled:
		set_guests_swaying(true)
	if not performance_active and _guests_swaying_enabled:
		set_guests_swaying(false)
	if music_particles == null:
		_maybe_log_performance_debug_state(performance_active)
		return
	music_particles.emitting = performance_active
	_maybe_log_performance_debug_state(performance_active)

func _exit_tree() -> void:
	if AnimationModule.debug_performance_enabled:
		DebugLog.info("[Performance]", _get_performance_debug_label(), "exit_tree", get_performance_debug_snapshot())
	set_guests_swaying(false)

func count_guests_in_range() -> int:
	if Global.NPCSpawner == null:
		return 0

	var count := 0
	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
		if is_guest_in_performance_range(guest):
			count += 1
	return count

func set_guests_swaying(value: bool) -> void:
	if _guests_swaying_enabled == value:
		return

	_guests_swaying_enabled = value
	if AnimationModule.debug_performance_enabled:
		DebugLog.info("[Performance]", _get_performance_debug_label(), "set_guests_swaying", value, get_performance_debug_snapshot())
	AnimationModule.set_music_sway_enabled(value)

func entertain_guests() -> int:
	if not has_active_performance() or Global.NPCSpawner == null:
		return 0

	var boosted_guest_count := 0
	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
		if not is_guest_in_performance_range(guest):
			continue
		guest.add_mood(get_mood_boost(), "Entertainment")
		boosted_guest_count += 1

	return boosted_guest_count

func is_guest_in_performance_range(guest: NPCGuest) -> bool:
	return _is_guest_in_range(guest)

func get_adjacent_performance_rooms() -> Array[RoomBase]:
	var adjacent_rooms: Array[RoomBase] = []
	var seen_room_ids := {}
	var min_x: int = x - 1
	var max_x: int = x + data.width
	var min_y: int = y - 1
	var max_y: int = y + data.height

	for scan_y in range(min_y, max_y + 1):
		var floor_rooms: Dictionary = Building.floors.get(scan_y, {})
		for room_value in floor_rooms.values():
			var candidate := room_value as RoomBase
			if candidate == null or candidate == self or candidate.data == null or candidate.is_outside_room:
				continue

			var candidate_left: int = candidate.x
			var candidate_right: int = candidate.x + candidate.data.width - 1
			var candidate_top: int = candidate.y
			var candidate_bottom: int = candidate.y + candidate.data.height - 1
			if candidate_right < min_x or candidate_left > max_x:
				continue
			if candidate_bottom < min_y or candidate_top > max_y:
				continue

			var room_id := candidate.get_instance_id()
			if seen_room_ids.has(room_id):
				continue
			seen_room_ids[room_id] = true
			adjacent_rooms.append(candidate)

	return adjacent_rooms

func _is_guest_in_range(guest: NPCGuest) -> bool:
	if not is_instance_valid(guest):
		return false

	var guest_room := Building.query.room_at_floor_position(guest.global_position) as RoomBase
	if guest_room == null or guest_room.data == null or guest_room.is_outside_room:
		return false
	if guest_room == self:
		return true

	return get_adjacent_performance_rooms().has(guest_room)

func get_performance_debug_snapshot() -> String:
	var particles_emitting := music_particles != null and music_particles.emitting
	var module_name := "<none>"
	if current_module != null:
		module_name = current_module.module_name
	return "%s active=%s sway=%s particles=%s worker=%s module=%s guests=%d" % [
		_get_performance_debug_label(),
		str(has_active_performance()),
		str(_guests_swaying_enabled),
		str(particles_emitting),
		_get_worker_debug_state(),
		module_name,
		count_guests_in_range(),
	]

func _get_performance_debug_label() -> String:
	return "%s(%d,%d)" % [get_script().get_global_name(), x, y]

func _get_worker_debug_state() -> String:
	if worker == null:
		return "<none>"
	if not is_instance_valid(worker):
		return "<stale>"
	return "%s job=%s room=%s" % [
		worker.get_debug_display_name(),
		Enum.Jobs.keys()[worker.current_job],
		_debug_describe_room(worker.current_job_room),
	]

func _debug_describe_room(room) -> String:
	if room == null:
		return "<none>"
	if not is_instance_valid(room):
		return "<stale>"
	return "%s(%d,%d)" % [room.get_script().get_global_name(), room.x, room.y]

func _capture_performance_debug_state() -> void:
	_debug_last_worker_state = _get_worker_debug_state()
	_debug_last_active_state = has_active_performance()
	_debug_last_particles_state = music_particles != null and music_particles.emitting

func _maybe_log_performance_debug_state(performance_active: bool) -> void:
	var worker_state := _get_worker_debug_state()
	var particles_state := music_particles != null and music_particles.emitting
	var changed := false
	if worker_state != _debug_last_worker_state:
		changed = true
	elif performance_active != _debug_last_active_state:
		changed = true
	elif particles_state != _debug_last_particles_state:
		changed = true
	if changed and AnimationModule.debug_performance_enabled:
		DebugLog.info("[Performance]", _get_performance_debug_label(), get_performance_debug_snapshot())
	_debug_last_worker_state = worker_state
	_debug_last_active_state = performance_active
	_debug_last_particles_state = particles_state
