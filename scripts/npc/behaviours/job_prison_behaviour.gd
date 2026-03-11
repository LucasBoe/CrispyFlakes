extends Behaviour
class_name JobPrisonBehaviour

var room : RoomPrison

static var occupied_rooms = []

func start_loop():
	room = try_get_room_if_not_occupied(data, RoomPrison, occupied_rooms)
	
func loop():
	while true:
		await move(room.get_random_floor_position())
		
		# arrest behaviour
		var to_arrest := get_npc_to_arrest()
		if to_arrest != null:
			var behaviour = (to_arrest.Behaviour.behaviour_instance as ArrestedBehaviour)
			await move(to_arrest.global_position)
			behaviour.cell = room
			await move(room.get_center_floor_position())
			
		# guard behaviour
		elif room.prisoners.size() > 0:
			await pause(10)
			
		else:
			RoomStatusHandler.notify(room, "no prisoners", Color.ORANGE)
			await pause(RoomStatusHandler.REFRESH_RATE-.5)
		
	#await progress(6, room.progressBar)
	
static func get_npc_to_arrest() -> NPCGuest:
	for g : NPCGuest in Global.NPCSpawner.guests:
		if g.Behaviour.behaviour_instance is ArrestedBehaviour\
		and not (g.Behaviour.behaviour_instance as ArrestedBehaviour).cell:
			return g
			
	return null
	
static func count_people_that_need_arrestment() -> int:
	var count = 0
	for g : NPCGuest in Global.NPCSpawner.guests:
		if g.Behaviour.behaviour_instance is ArrestedBehaviour\
		and not (g.Behaviour.behaviour_instance as ArrestedBehaviour).is_in_cell:
			count += 1
			
	return count
		
func stop_loop() -> BehaviourSaveData:
	room.worker = null
	occupied_rooms.erase(room)
	
	var save = super.stop_loop()
	save.room = room
	return save
