extends Behaviour
class_name JobOperaSingerBehaviour

var room: RoomOpera

static var occupied_rooms = []

func start_loop():
	_narrative = ["Singing for the crowd...", "Holding the stage...", "Performing an aria..."].pick_random()
	room = try_get_room_if_not_occupied(data, RoomOpera, occupied_rooms)

func loop():
	if room == null:
		return

	await move(room.get_center_stage_position())
	room.set_guests_swaying(true)

	while is_instance_valid(room) and room.worker == npc and not stopped:
		var duration := room.get_performance_interval()

		await progress(duration)

		if not is_instance_valid(room) or room.worker != npc or stopped:
			if AnimationModule.debug_performance_enabled:
				DebugLog.info("[Performance]", npc, "opera loop break", "room", room, "room_worker", room.worker if is_instance_valid(room) else null, "stopped", stopped)
			break

		room.set_guests_swaying(true)
		room.entertain_guests()

func stop_loop() -> BehaviourSaveData:
	if AnimationModule.debug_performance_enabled:
		DebugLog.info("[Performance]", npc, "opera stop_loop", "room", room, "room_worker", room.worker if is_instance_valid(room) else null)
	occupied_rooms.erase(room)
	if is_instance_valid(room):
		room.set_guests_swaying(false)
		room.worker = null

	var save = super.stop_loop()
	save.room = room
	return save
