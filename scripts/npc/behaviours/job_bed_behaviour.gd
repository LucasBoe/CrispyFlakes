extends Behaviour
class_name JobBedBehaviour

const CLEAN_DURATION := 6.0

var room: RoomBed

static var occupied_rooms = []

func loop():
	while true:
		_narrative = ["Looking for dirty beds...", "Checking the rooms...", "On cleaning duty..."].pick_random()
		room = _find_dirty_bed()

		if room == null:
			_change_to_idle()
			return

		occupied_rooms.append(room)
		room.worker = npc
		room.on_destroy_signal.connect(_change_to_idle)

		_narrative = ["Cleaning the bed...", "Changing the sheets...", "Making it fresh..."].pick_random()
		await move(room.get_center_floor_position())
		await progress(CLEAN_DURATION)

		if is_instance_valid(room):
			room.clean_bed()
			room.worker = null
			if room.on_destroy_signal.is_connected(_change_to_idle):
				room.on_destroy_signal.disconnect(_change_to_idle)

		occupied_rooms.erase(room)
		room = null

func _find_dirty_bed() -> RoomBed:
	for bed: RoomBed in get_all_rooms_of_type_ordered_by_distance(RoomBed):
		if bed.needs_cleaning and not occupied_rooms.has(bed):
			return bed
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
