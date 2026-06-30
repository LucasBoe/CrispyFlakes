extends NeedBehaviour
class_name NeedGamblingBehaviour

var room: RoomGambling

static func get_probability_by_needs(needs: NeedsModule) -> float:
	return needs.mood.strength * 0.25

func loop():
	_narrative = ["Looking for a game...", "Feeling lucky...", "Heading to the table..."].pick_random()
	room = get_least_loaded_room_of_type(
		RoomGambling,
		func(candidate: RoomGambling): return candidate.can_accept_guest(),
		func(candidate: RoomGambling): return candidate.max_guest_count - candidate.get_free_count(),
		func(candidate: RoomGambling): return candidate.max_guest_count
	)

	if room == null:
		await pause(2)
		return

	await move(room.get_random_floor_position())
	var guest := npc as NPCGuest
	if guest == null or not is_instance_valid(room):
		return

	await move(room.sit(guest))
	if stopped or not is_instance_valid(room) or not room.is_guest_seated(guest):
		return
	room.on_seated(guest)

	_narrative = ["Playing cards...", "Watching the draw...", "At the gambling table..."].pick_random()
	while is_instance_valid(room) and room.is_guest_seated(guest):
		if stopped:
			return
		await end_of_frame()

	if is_instance_valid(room) and room.is_guest_seated(guest):
		room.stand_up(guest)

func stop_loop() -> BehaviourSaveData:
	var guest := npc as NPCGuest
	if guest != null and is_instance_valid(room) and room.is_guest_seated(guest):
		room.stand_up(guest)
	return super.stop_loop()
