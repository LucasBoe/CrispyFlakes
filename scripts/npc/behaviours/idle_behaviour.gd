extends Behaviour

func loop():
	while isRunning:
		await pause(3)
		await move(npc.Navigation.get_random_target())
