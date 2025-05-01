extends Behaviour

func loop():
	while true:
		print("wait")
		await get_tree().create_timer(3.0).timeout
		npc.Navigation.set_target(npc.Navigation.get_random_target())
		
		while npc.Navigation.is_moving:	
			await get_tree().process_frame
