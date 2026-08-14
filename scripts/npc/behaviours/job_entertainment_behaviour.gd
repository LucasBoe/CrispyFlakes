extends Behaviour
class_name JobEntertainmentBehaviour

var room: RoomEntertainment
var _piano_sound : AudioStreamPlayer2D

static var occupied_rooms = []

func start_loop():
	_narrative = ["Entertaining the crowd...", "Playing for the guests...", "On stage..."].pick_random()
	room = try_get_room_if_not_occupied(data, RoomEntertainment, occupied_rooms)

func loop():
	if room == null:
		return

	var pos = (room.get_center_floor_position() + room.global_position) / 2.0
	
	await move(pos)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	npc.Animator.is_playing_piano = true
	_piano_sound = SoundPlayer.play_piano_loop(room.global_position)
	room.set_guests_swaying(true)

	while is_instance_valid(room) and room.worker == npc and not stopped:
		var duration := room.get_performance_interval()

		await progress(duration)

		if not is_instance_valid(room) or room.worker != npc or stopped:
			if AnimationModule.debug_performance_enabled:
				DebugLog.info("[Performance]", npc, "entertainment loop break", "room", room, "room_worker", room.worker if is_instance_valid(room) else null, "stopped", stopped)
			break

		room.set_guests_swaying(true)
		var boosted_guest_count := room.entertain_guests()
		#if boosted_guest_count > 0:
			#UiNotifications.create_notification_static(
				#"+%d mood" % boosted_guest_count,
				#room.get_notification_position(),
				#room.current_module.icon if room.current_module else null,
				#Color.WHITE,
				#1.2
			#)
		#else:
			#await pause(1)

func stop_loop() -> BehaviourSaveData:
	if AnimationModule.debug_performance_enabled:
		DebugLog.info("[Performance]", npc, "entertainment stop_loop", "room", room, "room_worker", room.worker if is_instance_valid(room) else null)
	npc.Animator.is_playing_piano = false
	if is_instance_valid(_piano_sound):
		_piano_sound.queue_free()
		_piano_sound = null
	if room != null:
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	occupied_rooms.erase(room)
	if is_instance_valid(room):
		room.set_guests_swaying(false)
		room.worker = null

	var save = super.stop_loop()
	save.room = room
	return save
