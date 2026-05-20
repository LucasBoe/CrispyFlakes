extends Node

signal flag_unlocked(flag: ProgressionItem.ProgressionFlag)
signal room_unlocked(room: RoomData)
signal item_unlocked(item: ProgressionItem)
signal item_completed(item: ProgressionItem)

const ALL_ITEMS := [
	preload("res://assets/resources/progression/prog_group_starter.tres"),
	preload("res://assets/resources/progression/prog_group_infrastructure_I.tres"),
	preload("res://assets/resources/progression/prog_group_infrastructure_II.tres"),
	preload("res://assets/resources/progression/prog_group_infrastructure_III.tres"),
	preload("res://assets/resources/progression/prog_group_infrastructure_IV.tres"),
	preload("res://assets/resources/progression/prog_group_infrastructure_V.tres"),
	preload("res://assets/resources/progression/prog_group_beverages_I.tres"),
	preload("res://assets/resources/progression/prog_group_beverages_II.tres"),
	preload("res://assets/resources/progression/prog_group_beverages_III.tres"),
	preload("res://assets/resources/progression/prog_group_beverages_IV.tres"),
	preload("res://assets/resources/progression/prog_group_electricity_I.tres"),
	preload("res://assets/resources/progression/prog_group_entertainment_I.tres"),
	preload("res://assets/resources/progression/prog_group_entertainment_II.tres"),
	preload("res://assets/resources/progression/prog_group_safety_I.tres"),
	preload("res://assets/resources/progression/prog_group_safety_II.tres"),
	preload("res://assets/resources/progression/prog_group_safety_III.tres"),
]

var _all_items: Array[ProgressionItem] = []
var _unlocked_flags: Dictionary = {}
var _unlocked_rooms: Array[RoomData] = []
var _unlocked_infrastructure: Array[InfrastructureData] = []
var _unlocked_items: Array[ProgressionItem] = []
var _completed_items: Array[ProgressionItem] = []
var _items_by_room: Dictionary = {}
var _items_by_infrastructure: Dictionary = {}
var _built_room_history: Dictionary = {}
var _built_infrastructure_history: Dictionary = {}
var _default_groups_unlocked := false

func _ready() -> void:
	if not GlobalEventHandler.on_room_created_signal.is_connected(_on_room_created):
		GlobalEventHandler.on_room_created_signal.connect(_on_room_created)
	if not GlobalEventHandler.on_infrastructure_changed_signal.is_connected(_on_infrastructure_changed):
		GlobalEventHandler.on_infrastructure_changed_signal.connect(_on_infrastructure_changed)

	Console.add_command("tree", console_unlock_all_progression, 0, 0, "Unlocks all progression groups.")
	_build_items()
	_rebuild_maps()

func get_all_items() -> Array[ProgressionItem]:
	return _all_items

func unlock_default_rooms() -> void:
	if _default_groups_unlocked:
		return
	_default_groups_unlocked = true
	_record_existing_buildables()
	for item in _all_items:
		if item.get_required_items().is_empty() and item.unlock_by_default_if_root:
			_unlock_item(item)
	_refresh_progression_states()

func console_unlock_all_progression() -> void:
	for item in _all_items:
		_unlock_item(item)
		_complete_item(item)
	Console.print_line("unlocked all progression groups")

func force_unlock(item: ProgressionItem) -> void:
	_unlock_item(item)
	_refresh_progression_states()

func is_item_unlocked(item: ProgressionItem) -> bool:
	return item in _unlocked_items

func is_item_revealed(item: ProgressionItem) -> bool:
	if item == null:
		return false
	var requirements := item.get_required_items()
	if requirements.is_empty():
		return item.unlock_by_default_if_root or is_item_unlocked(item)
	for requirement in requirements:
		if requirement == null or not is_item_unlocked(requirement):
			return false
	return true

func is_item_completed(item: ProgressionItem) -> bool:
	return item in _completed_items

func is_flag_set(flag: ProgressionItem.ProgressionFlag) -> bool:
	return _unlocked_flags.get(flag, false)

func is_room_unlocked(room: RoomData) -> bool:
	return room in _unlocked_rooms

func get_item_for_room(room: RoomData) -> ProgressionItem:
	return _items_by_room.get(room, null)

func get_item_for_infrastructure(data: InfrastructureData) -> ProgressionItem:
	return _items_by_infrastructure.get(data, null)

func is_room_build_unlocked(room: RoomData) -> bool:
	var item := get_item_for_room(room)
	return true if item == null else is_item_unlocked(item)

func is_infrastructure_build_unlocked(data: InfrastructureData) -> bool:
	var item := get_item_for_infrastructure(data)
	return true if item == null else is_item_unlocked(item)

func get_missing_requirements(item: ProgressionItem) -> Array[ProgressionItem]:
	var missing: Array[ProgressionItem] = []
	for requirement in item.get_required_items():
		if requirement != null and not is_item_completed(requirement):
			missing.append(requirement)
	return missing

func get_primary_missing_requirement(item: ProgressionItem) -> ProgressionItem:
	var missing := get_missing_requirements(item)
	return missing[0] if not missing.is_empty() else null

func get_item_total_content_count(item: ProgressionItem) -> int:
	return item.get_content_count()

func get_item_completed_content_count(item: ProgressionItem) -> int:
	var count := 0
	for room in item.get_unlocked_rooms():
		if _built_room_history.get(room, false):
			count += 1
	for data in item.get_unlocked_infrastructure():
		if _built_infrastructure_history.get(data, false):
			count += 1
	return count

func is_content_built(data) -> bool:
	if data is RoomData:
		return _built_room_history.get(data, false)
	if data is InfrastructureData:
		return _built_infrastructure_history.get(data, false)
	return false

func get_completed_item_count() -> int:
	return _completed_items.size()

func _build_items() -> void:
	_all_items.clear()
	for item in ALL_ITEMS:
		_all_items.append(item as ProgressionItem)

func _rebuild_maps() -> void:
	_items_by_room.clear()
	_items_by_infrastructure.clear()
	for item in _all_items:
		for room in item.get_unlocked_rooms():
			_items_by_room[room] = item
		for data in item.get_unlocked_infrastructure():
			_items_by_infrastructure[data] = item

func _record_existing_buildables() -> void:
	if not is_instance_valid(Building):
		return

	for floor in Building.floors.values():
		for room in floor.values():
			var room_instance := room as RoomBase
			if room_instance != null and room_instance.data != null:
				_built_room_history[room_instance.data] = true

	for data in _items_by_infrastructure.keys():
		if Building.infrastructure.count_cells_by_data(data) > 0:
			_built_infrastructure_history[data] = true

func _on_room_created(room: RoomBase) -> void:
	if room == null or room.data == null:
		return
	_built_room_history[room.data] = true
	_refresh_progression_states()

func _on_infrastructure_changed(_layer_name: StringName) -> void:
	if not is_instance_valid(Building.infrastructure):
		return
	for data in _items_by_infrastructure.keys():
		if Building.infrastructure.count_cells_by_data(data) > 0:
			_built_infrastructure_history[data] = true
	_refresh_progression_states()

func _refresh_progression_states() -> void:
	var changed := true
	while changed:
		changed = false
		for item in _all_items:
			if not is_item_unlocked(item) and _can_unlock(item):
				_unlock_item(item)
				changed = true
			if is_item_unlocked(item) and not is_item_completed(item) and _is_item_complete(item):
				_complete_item(item)
				changed = true

func _can_unlock(item: ProgressionItem) -> bool:
	var requirements := item.get_required_items()
	if requirements.is_empty():
		return false
	for requirement in requirements:
		if requirement == null or not is_item_completed(requirement):
			return false
	return true

func _unlock_item(item: ProgressionItem) -> void:
	if item == null or is_item_unlocked(item):
		return

	_unlocked_items.append(item)
	for room in item.get_unlocked_rooms():
		if not _unlocked_rooms.has(room):
			_unlocked_rooms.append(room)
			room_unlocked.emit(room)
	for data in item.get_unlocked_infrastructure():
		if not _unlocked_infrastructure.has(data):
			_unlocked_infrastructure.append(data)
	for flag in item.unlocks_flags:
		if flag != ProgressionItem.ProgressionFlag.NONE and not _unlocked_flags.get(flag, false):
			_unlocked_flags[flag] = true
			flag_unlocked.emit(flag)
	item_unlocked.emit(item)

func _is_item_complete(item: ProgressionItem) -> bool:
	var total := get_item_total_content_count(item)
	if total <= 0:
		return is_item_unlocked(item)
	return get_item_completed_content_count(item) >= total

func _complete_item(item: ProgressionItem) -> void:
	if item == null or is_item_completed(item):
		return
	_completed_items.append(item)
	item_completed.emit(item)
