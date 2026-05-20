extends Behaviour
class_name JobGeneratorWheelBehaviour

static var occupied_rooms: Array = []

var room: RoomGeneratorWheel = null

func start_loop() -> void:
	_narrative = ["Generating electricity...", "Running the wheel...", "Keeping the generator turning..."].pick_random()
	room = try_get_room_if_not_occupied(data, RoomGeneratorWheel, occupied_rooms) as RoomGeneratorWheel

func loop() -> void:
	if room == null:
		return

	await move(room.get_runner_position())
	if not is_instance_valid(room) or stopped:
		return

	room.set_generating(true)
	if npc.Animator != null:
		npc.Animator.x_orientation = 1
		npc.Animator.set_running_in_place(true)

	while is_instance_valid(room) and room.worker == npc and not stopped:
		await pause(0.25)

func stop_loop() -> BehaviourSaveData:
	if npc.Animator != null:
		npc.Animator.set_running_in_place(false)

	occupied_rooms.erase(room)
	if is_instance_valid(room):
		room.set_generating(false)
		room.worker = null

	var save := super.stop_loop()
	save.room = room
	return save
