extends Behaviour
class_name JobJunkBehaviour

var room : RoomJunk

static var occupied_rooms = []

func start_loop(data : BehaviourSaveData):
	room = try_get_room_if_not_occupied(data, RoomJunk, occupied_rooms)
	
func loop():
	
	if room == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
		
	occupied_rooms.append(room)
	room.worker = npc
	await move(room.get_random_floor_position())
	await progress(6, room.progressBar)
	
	occupied_rooms.erase(room)
	Global.Building.delete_room(room)
			
func custom_array_sort(a, b):
		return a[1] < b[1]
		
func stop_loop() -> BehaviourSaveData:
	room.worker = null
	occupied_rooms.erase(room)
	
	var save = super.stop_loop()
	save.room = room
	return save
