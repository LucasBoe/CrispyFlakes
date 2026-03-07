extends NeedBehaviour
class_name ArestedBehaviour

var is_in_cell = false

func loop():
	npc.Animator.handcuffs.show()
	while not is_in_cell:
		await pause(1)
		
	var room = Global.Building.get_closest_room_of_type(RoomBase, npc.global_position)
	while true:
		await move(room.get_random_floor_position())

func stop_loop():
	npc.Animator.handcuffs.hide()
