extends RoomOutsideBase
class_name RoomHorsePost

var tied_horses: Array = []  # Array of HorseNPC

func tie_horse(horse: Node2D) -> void:
	tied_horses.append(horse)

func untie_horse(horse: Node2D) -> void:
	tied_horses.erase(horse)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for horse in tied_horses:
			if is_instance_valid(horse):
				horse.on_post_destroyed()
		tied_horses.clear()
