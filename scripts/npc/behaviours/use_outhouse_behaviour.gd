extends Behaviour
class_name UseOuthouseBehaviour

var outhouse : RoomOuthouse;

func loop():
	
	outhouse = get_random_room_of_type(RoomOuthouse)
	
	if not outhouse:
		await pause(3)
		# loose satisfaction
		# prompt toilet icon?
		# leave?
		return
	
	await move(outhouse.get_random_floor_position())
	
	while outhouse.is_used_by_other_then(npc):
		await end_of_frame()
		
	await  move(outhouse.get_center_floor_position())
	npc.Animator.hide()
	outhouse.user = npc;
	await progress(3, outhouse.progressBar)
	npc.Animator.show()
	outhouse.user = null
		
	npc.Needs.satisfaction.strength += .3
	npc.notify(UiNotifications.ICON_PLUS_2)
