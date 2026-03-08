extends Behaviour
class_name StopFightBehaviour

var fight : Fight = null

func loop():
	while fight == null:
		await end_of_frame()
		
	await move(fight.room)
	fight.participants.append(npc)
		
	while fight.energy > 0.0:
		fight.energy -= .2
		await pause(1)
		
	npc.Behaviour.restore_previous_behaviour()
