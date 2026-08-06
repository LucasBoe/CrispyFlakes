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

	while true:
		var duration := room.get_performance_interval()

		await progress(duration)

		if not is_instance_valid(room):
			return

		room.set_guests_swaying(true)
		room.entertain_guests()

func stop_loop() -> BehaviourSaveData:
	occupied_rooms.erase(room)
	if is_instance_valid(room):
		room.set_guests_swaying(false)
		room.worker = null

	var save = super.stop_loop()
	save.room = room
	return save
