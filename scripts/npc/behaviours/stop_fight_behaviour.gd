extends Behaviour
class_name StopFightBehaviour

var fight: Fight = null
var arrived_at_room: bool = false
var arrest_target: NPCGuest = null
var arrest_room: RoomPrison = null
var actively_fighting: bool = false

func is_actively_fighting() -> bool:
	return actively_fighting

func loop():
	_narrative = ["Responding to a fight!", "There's trouble!", "On my way!"].pick_random()
	while fight == null:
		await end_of_frame()

	if not fight.participants.has(npc):
		fight.participants.append(npc)
	await move(fight.room)
	arrived_at_room = true
	actively_fighting = true
	_narrative = ["In the fight!", "Restoring order!", "Breaking it up!"].pick_random()

	while not fight.is_over:
		await end_of_frame()

	actively_fighting = false

	if fight.worker_won():
		if npc is NPCWorker:
			(npc as NPCWorker).resume_job_behaviour()
		else:
			npc.Behaviour.restore_previous_behaviour()
	elif fight.npc_won() and arrived_at_room:
		npc.Behaviour.set_behaviour(KnockedOutBehaviour)
	else:
		if npc is NPCWorker:
			(npc as NPCWorker).resume_job_behaviour()
		else:
			npc.Behaviour.restore_previous_behaviour()
