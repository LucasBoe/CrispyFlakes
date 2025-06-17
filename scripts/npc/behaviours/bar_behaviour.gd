extends Behaviour

var bar : RoomBar

func loop():
	bar = Global.Building.get_closest_room_of_type(RoomBar, npc.global_position)
	while isRunning:
		await progress(2, bar.progressBar)
		ResourceHandler.add_animated(Enum.Resources.MONEY, 4, bar.get_center_position())
		await move(bar.get_random_floor_position())
		await pause(0.5)
		await move(bar.get_random_floor_position())
