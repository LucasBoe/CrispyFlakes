extends Behaviour
class_name JobJunkBehaviour

var room : RoomJunk

static var occupied_rooms = []

func start_loop():
	room = try_get_room_if_not_occupied(data, RoomJunk, occupied_rooms)
	
func loop():
	for i in 3:
		_narrative = ["Clearing the junk...", "Hauling debris...", "Cleaning up the wreckage..."].pick_random()
		await move(room.get_random_floor_position())
		await progress(1)
	
	occupied_rooms.erase(room)
	Building.replace_with_empty(room)
			
func custom_array_sort(a, b):
		return a[1] < b[1]
		
func stop_loop() -> BehaviourSaveData:
	room.worker = null
	occupied_rooms.erase(room)
	
	var save = super.stop_loop()
	save.room = room
	return save
