extends Behaviour
class_name JobEntertainmentBehaviour

var room: RoomEntertainment

static var occupied_rooms = []

func start_loop():
	room = try_get_room_if_not_occupied(data, RoomEntertainment, occupied_rooms)

func loop():
	if room == null:
		return

	var pos = (room.get_center_floor_position() + room.global_position) / 2.0
	
	await move(pos)
	npc.Animator.set_z(Enums.ZLayer.NPC_BEHIND_ROOM_CONTENT)

	while true:
		var duration := room.get_performance_interval()
		await progress(duration)

		if not is_instance_valid(room):
			return

		var boosted_guest_count := room.entertain_floor()
		if boosted_guest_count > 0:
			UiNotifications.create_notification_static(
				"+%d mood" % boosted_guest_count,
				room.get_notification_position(),
				room.current_module.icon if room.current_module else null,
				Color.WHITE,
				1.2
			)
		else:
			await pause(1)

func stop_loop() -> BehaviourSaveData:
	npc.Animator.set_z(Enums.ZLayer.NPC_DEFAULT)
	occupied_rooms.erase(room)
	if is_instance_valid(room):
		room.worker = null

	var save = super.stop_loop()
	save.room = room
	return save
