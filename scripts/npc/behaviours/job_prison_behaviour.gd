extends Behaviour
class_name JobPrisonBehaviour

var room : RoomPrison

static var occupied_rooms = []

func start_loop(data : BehaviourSaveData):
	room = try_get_room_if_not_occupied(data, RoomPrison, occupied_rooms)
	
func loop():
	while true:
		await move(room.get_random_floor_position())
		var has_prisoners = room.prisoners.size() > 0
		var has_potential_arrest = count_people_that_need_arrestment()
			
		if not has_prisoners and not has_potential_arrest:
			RoomStatusHandler.notify(room, "no prisoners", Color.ORANGE)
			await pause(RoomStatusHandler.REFRESH_RATE-.5)
		
	#await progress(6, room.progressBar)
	
static func count_people_that_need_arrestment() -> int:
	var count = 0
	for g : NPCGuest in Global.NPCSpawner.guests:
		if g.Behaviour.behaviour_instance is ArestedBehaviour\
		and not (g.Behaviour.behaviour_instance as ArestedBehaviour).is_in_cell:
			count+=1
			
	return count
		
func stop_loop() -> BehaviourSaveData:
	room.worker = null
	occupied_rooms.erase(room)
	
	var save = super.stop_loop()
	save.room = room
	return save
