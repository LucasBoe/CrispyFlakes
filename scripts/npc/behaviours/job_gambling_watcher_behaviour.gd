extends Behaviour
class_name JobGamblingWatcherBehaviour

static var occupied_rooms: Array = []

var room: RoomGambling

func start_loop():
	var watcher := npc as NPCWorker
	if watcher != null and watcher.current_job_room is RoomGambling:
		room = watcher.current_job_room as RoomGambling
	else:
		room = get_least_loaded_room_of_type(
			RoomGambling,
			func(candidate: RoomGambling): return candidate.worker == null,
			func(_candidate: RoomGambling): return 0,
			func(_candidate: RoomGambling): return 1
		) as RoomGambling

	if watcher == null or room == null or occupied_rooms.has(room) or not room.assign_watcher(watcher):
		_change_to_idle()
		return

	occupied_rooms.append(room)
	room.on_destroy_signal.connect(_change_to_idle)

func loop():
	if room == null:
		return

	var should_wait_for_round := room.loop_enabled \
		or room.is_configuring_round() \
		or room.has_selected_jackpot() \
		or room.get_seated_guest_count() > 0
	if not room.has_active_round() and not should_wait_for_round:
		RoomStatusHandler.notify(room, "no round", Color.ORANGE)
		await pause(0.5)
		_change_to_idle()
		return

	_narrative = ["Watching the cards...", "Keeping an eye out...", "Guarding the table..."].pick_random()
	await move(room.get_watcher_position())
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)

	while is_instance_valid(room) and room.worker == npc and (room.has_active_round() or room.loop_enabled or room.is_configuring_round() or room.has_selected_jackpot() or room.get_seated_guest_count() > 0):
		await pause(0.25)

func stop_loop() -> BehaviourSaveData:
	occupied_rooms.erase(room)
	var watcher := npc as NPCWorker
	if is_instance_valid(room) and watcher != null:
		room.remove_watcher(watcher)
	if is_instance_valid(npc):
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)

	var save = super.stop_loop()
	save.room = room
	return save
