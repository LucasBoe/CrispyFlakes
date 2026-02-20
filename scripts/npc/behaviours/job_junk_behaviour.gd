extends Behaviour
class_name JobJunkBehaviour

var room : RoomJunk

static var occupied_rooms = []

func loop():
	
	room = Global.Building.get_closest_room_of_type(RoomJunk, npc.global_position, occupied_rooms)
	
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

func stop_loop():
	room.worker = null
	occupied_rooms.erase(room)
