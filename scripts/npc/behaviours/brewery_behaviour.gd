extends Behaviour

func loop():
	while isRunning:
		await endOfFrame()
