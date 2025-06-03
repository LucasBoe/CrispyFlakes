extends Behaviour

func loop():
	while isRunning:
		await pause(3)
		npc.Navigation.set_target(npc.Navigation.get_random_target())
		
		while npc.Navigation.is_moving:	
			await endOfFrame()
