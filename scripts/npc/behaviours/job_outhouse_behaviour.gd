extends Behaviour
class_name JobOuthouseBehaviour

const CLEAN_DURATION = 8.0

var room: RoomOuthouse

static var occupied_rooms = []

func loop():
	while true:
		room = _find_dirty_outhouse()

		if room == null:
			_change_to_idle()
			return

		occupied_rooms.append(room)
		room.worker = npc
		room.on_destroy_signal.connect(_change_to_idle)

		await move(room.get_center_floor_position())
		await progress(CLEAN_DURATION)

		if is_instance_valid(room):
			room.uses = 0
			room.worker = null
			if room.on_destroy_signal.is_connected(_change_to_idle):
				room.on_destroy_signal.disconnect(_change_to_idle)

		occupied_rooms.erase(room)
		room = null

func _find_dirty_outhouse() -> RoomOuthouse:
	for outhouse: RoomOuthouse in get_all_rooms_of_type_ordered_by_distance(RoomOuthouse):
		if outhouse.is_full() and not occupied_rooms.has(outhouse):
			return outhouse
	return null

func stop_loop() -> BehaviourSaveData:
	if is_instance_valid(room):
		room.worker = null
		if room.on_destroy_signal.is_connected(_change_to_idle):
			room.on_destroy_signal.disconnect(_change_to_idle)
	occupied_rooms.erase(room)

	var save = super.stop_loop()
	save.room = room
	return save
