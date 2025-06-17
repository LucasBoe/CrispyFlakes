extends Behaviour

var bar : RoomBar

func loop():
	bar = Global.Building.get_closest_room_of_type(RoomBar, npc.global_position)
	while isRunning:
		await pause(4)
		ResourceHandler.add_animated(Enum.Resources.MONEY, 4, bar.get_center_position())
