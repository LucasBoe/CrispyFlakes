extends Behaviour
class_name JobDiggingBehaviour

const DIG_DURATION := 24.0
const DIG_SOUND_INTERVAL := 2.0

var room

static var occupied_rooms = []

func start_loop():
	room = try_get_room_if_not_occupied(data, RoomDigging, occupied_rooms)

func loop():
	if room == null:
		return

	_narrative = ["Digging out the basement...", "Clearing hard-packed dirt...", "Carving out a new room..."].pick_random()
	await move(room.get_dig_start_position())
	await _dig_room()

	if not is_instance_valid(room) or stopped:
		return

	room.set_dig_progress(1.0)
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
	npc.Animator.direction = Vector2.RIGHT if room.dig_direction > 0.0 else Vector2.LEFT

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
