extends Behaviour
class_name UseOuthouseBehaviour

var outhouse : RoomOuthouse;

func loop():
	
	outhouse = Global.Building.get_all_rooms_of_type(RoomOuthouse).pick_random();
	
	if not outhouse:
		await pause(3)
		# loose satisfaction
		# prompt toilet icon?
		# leave?
		return
	
	await move(outhouse.get_random_floor_position())
	
	while outhouse.is_used_by_other_then(npc):
		await endOfFrame()
		
	await  move(outhouse.get_center_floor_position())
	npc.Animator.hide()
	outhouse.user = npc;
	await progress(3, outhouse.progressBar)
	npc.Animator.show()
	outhouse.user = null
		
	npc.Needs.satisfaction.strength += .3
