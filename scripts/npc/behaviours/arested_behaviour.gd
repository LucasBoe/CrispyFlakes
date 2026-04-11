extends NeedBehaviour
class_name ArrestedBehaviour

var cell : RoomPrison = null
var is_in_cell = false

func loop():
	npc.Animator.handcuffs.show()

	while not cell:
		await pause(1)

	await move(cell.get_center_floor_position())
	npc.Animator.set_z(Enums.ZLayer.NPC_BEHIND_ROOM_DEEP)
	is_in_cell = true
	cell.prisoners.append(npc)
	await move(cell.get_random_floor_position())

	while true:
		await pause(2)

func stop_loop():
	npc.Animator.handcuffs.hide()
	if is_instance_valid(cell):
		cell.prisoners.erase(npc)
	npc.Animator.set_z(Enums.ZLayer.NPC_DEFAULT)
	return super.stop_loop()
