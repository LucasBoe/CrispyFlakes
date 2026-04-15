extends RoomOutsideBase
class_name RoomHorsePost

@onready var slots_root: Node2D = $Slots

var slot_positions: Array[Vector2] = []
var tied_horses := {}

func _ready() -> void:
	for child in slots_root.get_children():
		if child is Node2D:
			slot_positions.append((child as Node2D).position)

func tie_horse(horse: Node2D) -> bool:
	if not can_accept_horse():
		return false
	var slot_index := _get_next_free_slot_index()
	if slot_index < 0:
		return false
	tied_horses[horse] = slot_index
	show_horse_count_notification()
	return true

func untie_horse(horse: Node2D) -> void:
	tied_horses.erase(horse)
	show_horse_count_notification()

func can_accept_horse() -> bool:
	_cleanup_tied_horses()
	return tied_horses.size() < get_max_horse_count()

func get_horse_count() -> int:
	_cleanup_tied_horses()
	return tied_horses.size()

func get_max_horse_count() -> int:
	return slot_positions.size()

func get_tie_position(horse: Node2D) -> Vector2:
	_cleanup_tied_horses()
	var slot_index = tied_horses.get(horse, -1)
	if slot_index < 0 or slot_index >= slot_positions.size():
		return get_center_floor_position()
	return to_global(slot_positions[slot_index])

func _get_next_free_slot_index() -> int:
	var used_slots := tied_horses.values()
	for i in get_max_horse_count():
		if not used_slots.has(i):
			return i
	return -1

func _cleanup_tied_horses() -> void:
	for horse in tied_horses.keys():
		if not is_instance_valid(horse):
			tied_horses.erase(horse)

func show_horse_count_notification():
	var txt = str(get_horse_count(), "/", get_max_horse_count())
	UiNotifications.create_notification_static(txt, get_center_position(), null, Color.BLACK if can_accept_horse() else Color.RED)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for horse in tied_horses.keys():
			if is_instance_valid(horse):
				horse.on_post_destroyed()
		tied_horses.clear()
