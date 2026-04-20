extends RoomOutsideBase
class_name RoomHorsePost

var tied_horses := {}

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	_refresh_visuals()

func _on_module_bought(module) -> void:
	super._on_module_bought(module)
	if not module.bought:
		return
	_refresh_visuals()
	show_horse_count_notification()

func _refresh_visuals() -> void:
	pass

func _get_active_slots_root() -> Node2D:
	if current_module != null:
		var module_slots := current_module.get_node_or_null("Slots") as Node2D
		if module_slots != null:
			return module_slots
	return null

func _get_slot_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var slots_root := _get_active_slots_root()
	if slots_root == null:
		return positions

	for child in slots_root.get_children():
		if child is Node2D:
			positions.append((child as Node2D).global_position)
	return positions

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
	return _get_slot_positions().size()

func get_tie_position(horse: Node2D) -> Vector2:
	_cleanup_tied_horses()
	var slot_index = tied_horses.get(horse, -1)
	var slot_positions := _get_slot_positions()
	if slot_index < 0 or slot_index >= slot_positions.size():
		return get_center_floor_position()
	return slot_positions[slot_index]

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

func show_horse_count_notification() -> void:
	var txt = str(get_horse_count(), "/", get_max_horse_count())
	UiNotifications.create_notification_static(txt, get_center_position(), null, Color.BLACK if can_accept_horse() else Color.RED)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		for horse in tied_horses.keys():
			if is_instance_valid(horse):
				horse.on_post_destroyed()
		tied_horses.clear()
