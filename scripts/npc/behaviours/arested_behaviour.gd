extends NeedBehaviour
class_name ArrestedBehaviour

var cell : RoomPrison = null
var is_in_cell = false

func loop():
	_narrative = ["Handcuffed and waiting...", "Under arrest!"].pick_random()
	npc.Animator.handcuffs.show()

	while not cell:
		await pause(1)

	_narrative = ["Heading to the cell...", "Being marched over...", "On their way to lockup..."].pick_random()
	await move(cell.get_center_floor_position())
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_ROOM_DEEP)
	is_in_cell = true
	cell.prisoners.append(npc)
	_narrative = ["In custody.", "Going nowhere fast...", "Locked up."].pick_random()
	await move(cell.get_random_floor_position())

	while true:
		await pause(2)

func stop_loop():
	npc.Animator.handcuffs.hide()
	if is_instance_valid(cell):
		cell.prisoners.erase(npc)
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	return super.stop_loop()
