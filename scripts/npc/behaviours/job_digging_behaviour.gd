extends Behaviour
class_name JobDiggingBehaviour

const DIG_DURATION := 48.0
const DIG_SOUND_INTERVAL := 1.0

var room

static var occupied_rooms = []

func start_loop():
	room = _claim_room()

func loop():
	if room == null:
		return
	if room.get_assignment_anchor_room() == null:
		_clear_pickaxe()
		_release_room()
		_change_to_idle()
		return

	_narrative = ["Digging out the basement...", "Clearing hard-packed dirt...", "Carving out a new room..."].pick_random()
	_ensure_pickaxe()
	await move(room.get_dig_start_position())
	await _dig_room()

	if not is_instance_valid(room) or stopped:
		_clear_pickaxe()
		return

	room.set_dig_progress(1.0)
	_clear_pickaxe()
	occupied_rooms.erase(room)
	Building.replace_with_empty(room)
	_refresh_worker_z_for_current_room()

func _dig_room() -> void:
	var duration := _get_progress_duration(DIG_DURATION)
	var elapsed := 0.0
	var sound_elapsed := DIG_SOUND_INTERVAL
	var start_pos: Vector2 = room.get_dig_start_position()
	var end_pos: Vector2 = room.get_dig_end_position()

	npc.Navigation.stop_navigation()
	npc.Navigation.is_moving = true
	npc.Animator.direction = room.get_dig_animation_direction()

	while elapsed < duration:
		if stopped or not is_instance_valid(room):
			npc.Navigation.is_moving = false
			return
		elapsed += npc.get_process_delta_time()
		sound_elapsed += npc.get_process_delta_time()
		var progress: float = minf(elapsed / duration, 1.0)
		npc.global_position = start_pos.lerp(end_pos, progress)
		room.set_dig_progress(progress)
		if sound_elapsed >= DIG_SOUND_INTERVAL:
			SoundPlayer.play_digging(npc.global_position)
			sound_elapsed = 0.0
		await end_of_frame()

	npc.Navigation.is_moving = false
	npc.Animator.direction = Vector2.ZERO

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(room):
		room.worker = null
	if is_instance_valid(npc) and npc.Navigation != null:
		npc.Navigation.is_moving = false
		npc.Animator.direction = Vector2.ZERO
	_clear_pickaxe()
	occupied_rooms.erase(room)

	var save = super.stop_loop()
	save.room = room
	return save

func _refresh_worker_z_for_current_room() -> void:
	if not is_instance_valid(npc) or npc.Animator == null:
		return

	var current_room := Building.query.room_at_floor_position(npc.global_position) as RoomBase
	var z_layer: Enum.ZLayer = Enum.ZLayer.NPC_OUTSIDE if current_room == null or current_room.is_outside_room else Enum.ZLayer.NPC_DEFAULT
	npc.Animator.set_z(z_layer)

func _claim_room() -> RoomDigging:
	var reachable_rooms: Array = npc.Navigation.get_reachable_rooms()
	var target_room := _get_saved_room(reachable_rooms)
	if target_room == null:
		target_room = _get_closest_workable_room(reachable_rooms)

	if target_room == null:
		_change_to_idle()
		return null

	occupied_rooms.append(target_room)
	target_room.worker = npc
	if not target_room.on_destroy_signal.is_connected(_change_to_idle):
		target_room.on_destroy_signal.connect(_change_to_idle)
	return target_room

func _get_saved_room(reachable_rooms: Array) -> RoomDigging:
	if data == null or data.room == null or data.room is not RoomDigging:
		return null

	var saved_room := data.room as RoomDigging
	var workable := _can_work_room(saved_room, reachable_rooms)
	if occupied_rooms.has(saved_room) or not workable:
		return null
	return saved_room

func _get_closest_workable_room(reachable_rooms: Array) -> RoomDigging:
	var closest_room: RoomDigging = null
	var closest_distance := INF

	for candidate in Building.query.all_rooms_of_type(RoomDigging):
		var workable := _can_work_room(candidate, reachable_rooms)
		if occupied_rooms.has(candidate):
			continue
		if not workable:
			continue

		var distance := npc.global_position.distance_squared_to(candidate.get_dig_start_position())
		if distance < closest_distance:
			closest_distance = distance
			closest_room = candidate

	return closest_room

func _can_work_room(candidate: RoomDigging, reachable_rooms: Array) -> bool:
	if not is_instance_valid(candidate):
		return false

	var anchor_room: RoomBase = candidate.get_assignment_anchor_room()
	if anchor_room == null:
		return false
	if reachable_rooms.is_empty():
		return true
	return anchor_room in reachable_rooms

func _release_room() -> void:
	if is_instance_valid(room):
		room.worker = null
	occupied_rooms.erase(room)

func _ensure_pickaxe() -> void:
	if not is_instance_valid(npc) or npc.Item == null:
		return
	if npc.Item.is_item(Enum.Items.PICKAXE):
		return
	if npc.Item.current_item != null:
		npc.Item.drop_current()
	var pickaxe := Global.ItemSpawner.create(Enum.Items.PICKAXE, npc.global_position)
	npc.Item.pick_up(pickaxe)

func _clear_pickaxe() -> void:
	if not is_instance_valid(npc) or npc.Item == null:
		return
	if not npc.Item.is_item(Enum.Items.PICKAXE):
		return
	npc.Item.current_item.destroy()
	npc.Item.current_item = null
