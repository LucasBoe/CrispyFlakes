extends Behaviour
class_name StopFightBehaviour

var fight: Fight = null
var arrived_at_room: bool = false
var arrest_target: NPCGuest = null
var arrest_room: RoomPrison = null

func loop():
	while fight == null:
		await end_of_frame()

	fight.participants.append(npc)
	await move(fight.room)
	arrived_at_room = true

	while not fight.is_over:
		await end_of_frame()

	if fight.worker_won():
		if arrest_target != null and arrest_room != null and is_instance_valid(arrest_target):
			var behaviour = arrest_target.Behaviour.behaviour_instance as ArrestedBehaviour
			if behaviour != null:
				behaviour.cell = arrest_room
				await move(arrest_room.get_center_floor_position())
		npc.Behaviour.restore_previous_behaviour()
	elif fight.npc_won() and arrived_at_room:
		npc.Behaviour.set_behaviour(KnockedOutBehaviour)
	else:
		npc.Behaviour.restore_previous_behaviour()
