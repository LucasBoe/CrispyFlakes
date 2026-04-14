extends RoomOutsideBase
class_name RoomHorsePost

const MAX_HORSES := 1

var tied_horses: Array = []  # Array of HorseNPC

func tie_horse(horse: Node2D) -> bool:
	if not can_accept_horse():
		return false
	tied_horses.append(horse)
	show_horse_count_notification()
	return true

func untie_horse(horse: Node2D) -> void:
	tied_horses.erase(horse)
	show_horse_count_notification()

func can_accept_horse() -> bool:
	_cleanup_tied_horses()
	return tied_horses.size() < MAX_HORSES

func get_horse_count() -> int:
	_cleanup_tied_horses()
	return tied_horses.size()

func _cleanup_tied_horses() -> void:
	for i in range(tied_horses.size() - 1, -1, -1):
		if not is_instance_valid(tied_horses[i]):
			tied_horses.remove_at(i)

func show_horse_count_notification():
	var txt = str(get_horse_count(), "/", MAX_HORSES)
	UiNotifications.create_notification_static(txt, get_center_position(), null, Color.BLACK if can_accept_horse() else Color.RED)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for horse in tied_horses:
			if is_instance_valid(horse):
				horse.on_post_destroyed()
		tied_horses.clear()
