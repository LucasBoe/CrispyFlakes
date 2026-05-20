extends Node

const SAVE_PATH := "user://simple_save.json"
const SAVE_VERSION := 4

func _ready() -> void:
	Console.add_command("save", console_save, 0, 0, "Saves placed rooms plus worker and guest positions.")
	Console.add_command("load", console_load, 0, 0, "Loads the simple room and NPC save file.")

func console_save() -> void:
	var rooms := _serialize_rooms()
	var water_pipes := _serialize_water_pipes()
	var electricity_tiles := _serialize_electricity_tiles()
	var stored_items := _serialize_stored_items()
	var loose_items := _serialize_loose_items()
	var workers := _serialize_workers()
	var guests := _serialize_guests()
	var payload := {
		"version": SAVE_VERSION,
		"rooms": rooms,
		"water_pipes": water_pipes,
		"electricity_tiles": electricity_tiles,
		"stored_items": stored_items,
		"loose_items": loose_items,
		"workers": workers,
		"guests": guests,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		Console.print_error("Failed to open %s for writing." % ProjectSettings.globalize_path(SAVE_PATH))
		return

	file.store_string(JSON.stringify(payload, "\t"))
	Console.print_line("Saved %d rooms, %d pipes, %d electricity tiles, %d stored items, %d loose items, %d workers, %d guests to %s." % [
		rooms.size(),
		water_pipes.size(),
		electricity_tiles.size(),
		stored_items.size(),
		loose_items.size(),
		workers.size(),
		guests.size(),
		ProjectSettings.globalize_path(SAVE_PATH),
	])

func console_load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		Console.print_error("No save file found at %s." % ProjectSettings.globalize_path(SAVE_PATH))
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		Console.print_error("Failed to open %s for reading." % ProjectSettings.globalize_path(SAVE_PATH))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or parsed is not Dictionary:
		Console.print_error("Save file is not valid JSON.")
		return

	var save_data := parsed as Dictionary
	await _apply_save(save_data)

	var room_count := _get_array(save_data, "rooms").size()
	var pipe_count := _get_array(save_data, "water_pipes").size()
	var electricity_count := _get_array(save_data, "electricity_tiles").size()
	var stored_item_count := _get_array(save_data, "stored_items").size()
	var loose_item_count := _get_array(save_data, "loose_items").size()
	var worker_count := _get_array(save_data, "workers").size()
	var guest_count := _get_array(save_data, "guests").size()
	Console.print_line("Loaded %d rooms, %d pipes, %d electricity tiles, %d stored items, %d loose items, %d workers, %d guests from %s." % [
		room_count,
		pipe_count,
		electricity_count,
		stored_item_count,
		loose_item_count,
		worker_count,
		guest_count,
		ProjectSettings.globalize_path(SAVE_PATH),
	])

func _apply_save(save_data: Dictionary) -> void:
	TimeHandler.push_pause_lock(self)
	var previous_auto_spawn: bool = Global.should_auto_spawn_guests
	Global.should_auto_spawn_guests = false

	_clear_active_fights()
	_clear_active_fires()
	_clear_loose_items()
	_clear_spawned_npcs()
	_clear_building()

	await get_tree().process_frame

	_restore_rooms(_get_array(save_data, "rooms"))
	_restore_water_pipes(_get_array(save_data, "water_pipes"))
	_restore_electricity_tiles(_get_array(save_data, "electricity_tiles"))
	_restore_stored_items(_get_array(save_data, "stored_items"))
	_restore_loose_items(_get_array(save_data, "loose_items"))
	_restore_workers(_get_array(save_data, "workers"))
	_restore_guests(_get_array(save_data, "guests"))

	await get_tree().process_frame

	Global.should_auto_spawn_guests = previous_auto_spawn
	TimeHandler.pop_pause_lock(self)

func _serialize_rooms() -> Array[Dictionary]:
	var rooms: Array[Dictionary] = []
	for room: RoomBase in _get_unique_rooms():
		if room.data == null:
			continue
		var resource_path := _get_room_resource_path(room)
		if resource_path.is_empty():
			continue
		var entry := {
			"resource_path": resource_path,
			"x": room.x,
			"y": room.y,
		}
		var state := _serialize_room_state(room)
		if not state.is_empty():
			entry["state"] = state
		rooms.append(entry)

	rooms.sort_custom(func(a: Dictionary, b: Dictionary): return _sort_grid_entries(a, b))
	return rooms

func _serialize_water_pipes() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	if not is_instance_valid(Building.infrastructure):
		return cells

	for cell: Vector2i in Building.infrastructure.get_layer_cells(BuildingInfrastructure.WATER_LAYER):
		cells.append(_serialize_room_index(cell))

	cells.sort_custom(func(a: Dictionary, b: Dictionary): return _sort_grid_entries(a, b))
	return cells

func _serialize_electricity_tiles() -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	if not is_instance_valid(Building.infrastructure):
		return cells

	for cell: Vector2i in Building.infrastructure.get_layer_cells(BuildingInfrastructure.ELECTRICITY_LAYER):
		cells.append(_serialize_room_index(cell))

	cells.sort_custom(func(a: Dictionary, b: Dictionary): return _sort_grid_entries(a, b))
	return cells

func _serialize_stored_items() -> Array[Dictionary]:
	var stored_items: Array[Dictionary] = []
	for room: RoomBase in _get_unique_rooms():
		if room is not RoomStorageBase:
			continue

		var storage := room as RoomStorageBase
		for slot_index in storage.get_slot_capacity():
			var item := storage.get_item_at_slot(slot_index)
			if item == null:
				continue

			var entry := _serialize_item(item)
			entry["room"] = _serialize_room_index(Vector2i(storage.x, storage.y))
			entry["slot"] = slot_index
			stored_items.append(entry)

	stored_items.sort_custom(func(a: Dictionary, b: Dictionary): return _sort_storage_entries(a, b))
	return stored_items

func _serialize_loose_items() -> Array[Dictionary]:
	var loose_items: Array[Dictionary] = []
	if Global.ItemSpawner == null:
		return loose_items

	for child in Global.ItemSpawner.get_children():
		var item := child as Item
		if item == null or not is_instance_valid(item):
			continue

		var entry := _serialize_item(item)
		entry["position"] = _serialize_vector2(item.global_position)
		loose_items.append(entry)

	return loose_items

func _serialize_workers() -> Array[Dictionary]:
	var workers: Array[Dictionary] = []
	if Global.NPCSpawner == null:
		return workers

	for worker: NPCWorker in Global.NPCSpawner.workers:
		if not is_instance_valid(worker):
			continue

		var job := _sanitize_job(int(worker.current_job))
		var job_room := _sanitize_job_room_for_job(worker.current_job_room as RoomBase, job)
		var entry := {
			"name": worker.character_name,
			"position": _serialize_vector2(worker.global_position),
			"job": job,
		}
		if is_instance_valid(job_room):
			entry["job_room"] = _serialize_room_index(Vector2i(job_room.x, job_room.y))
		workers.append(entry)

	return workers

func _serialize_guests() -> Array[Dictionary]:
	var guests: Array[Dictionary] = []
	if Global.NPCSpawner == null:
		return guests

	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not is_instance_valid(guest):
			continue
		guests.append({
			"name": guest.character_name,
			"position": _serialize_vector2(guest.global_position),
		})

	return guests

func _restore_rooms(entries: Array) -> void:
	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue

		var entry := entry_variant as Dictionary
		var room_data := _get_room_data_for_restore(entry)
		if room_data == null:
			continue

		Building.set_room(room_data, int(entry.get("x", 0)), int(entry.get("y", 0)), false)

	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var room := Building.get_room_from_index(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))) as RoomBase
		if room == null:
			continue
		room.x = int(entry.get("x", 0))
		room.y = int(entry.get("y", 0))
		room.is_basement = room.y < 0

	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var room := Building.get_room_from_index(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))) as RoomBase
		if room == null:
			continue
		room.init_room(room.x, room.y)
		_restore_room_state(room, entry.get("state", {}))

	Building.update_foreground_tiles()

func _restore_water_pipes(entries: Array) -> void:
	if not is_instance_valid(Building.infrastructure):
		return

	var cells: Array[Vector2i] = []
	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue
		var entry := entry_variant as Dictionary
		cells.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))

	if cells.is_empty():
		return

	Building.infrastructure.restore_layer_cells(Building.infrastructure_data_water_pipe, cells)

func _restore_electricity_tiles(entries: Array) -> void:
	if not is_instance_valid(Building.infrastructure):
		return

	var cells: Array[Vector2i] = []
	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue
		var entry := entry_variant as Dictionary
		cells.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))

	if cells.is_empty():
		return

	Building.infrastructure.restore_layer_cells(Building.infrastructure_data_electricity, cells)

func _restore_stored_items(entries: Array) -> void:
	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue

		var entry := entry_variant as Dictionary
		var storage := _room_from_variant(entry.get("room", {})) as RoomStorageBase
		if storage == null:
			continue

		var item := _restore_item(entry)
		if item == null:
			continue

		if not storage.restore_item_to_slot(item, int(entry.get("slot", -1))):
			item.queue_free()

func _restore_loose_items(entries: Array) -> void:
	if Global.ItemSpawner == null:
		return

	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue

		var entry := entry_variant as Dictionary
		var item := _restore_item(entry)
		if item == null:
			continue

		Global.ItemSpawner.add_child(item)
		item.global_position = _deserialize_vector2(entry.get("position", {}))
		item.global_rotation = 0.0
		item.scale = Vector2.ONE
		Global.ItemSpawner.items.append(item)
		LooseItemHandler.register_loose_item_instance(item)

func _restore_workers(entries: Array) -> void:
	if Global.NPCSpawner == null:
		return

	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue

		var entry := entry_variant as Dictionary
		var worker := Global.NPCSpawner.spawn_new_worker(_deserialize_vector2(entry.get("position", {})), true, String(entry.get("name", ""))) as NPCWorker
		if worker == null:
			continue

		var job := _sanitize_job(int(entry.get("job", Enum.Jobs.IDLE)))
		var job_room := _sanitize_job_room_for_job(_room_from_variant(entry.get("job_room", {})), job)
		_restore_worker_assignment(worker, job, job_room)

func _restore_guests(entries: Array) -> void:
	if Global.NPCSpawner == null:
		return

	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue

		var entry := entry_variant as Dictionary
		Global.NPCSpawner.spawn_restored_guest(
			_deserialize_vector2(entry.get("position", {})),
			String(entry.get("name", ""))
		)

func _restore_worker_assignment(worker: NPCWorker, job: int, job_room: RoomBase) -> void:
	worker.current_job = job
	worker.current_job_room = job_room
	JobHandler.on_job_changed(worker, job)

	var behaviour_script = Enum.job_to_behaviour(job)
	if behaviour_script == null:
		behaviour_script = Enum.job_to_behaviour(Enum.Jobs.IDLE)
		worker.current_job = Enum.Jobs.IDLE
		worker.current_job_room = null

	var behaviour_data = null
	if job_room != null and job != Enum.Jobs.IDLE:
		behaviour_data = BehaviourSaveData.new(behaviour_script)
		behaviour_data.room = job_room

	worker.Behaviour.set_behaviour(behaviour_script, behaviour_data)

func _clear_active_fights() -> void:
	for fight: Fight in FightHandler.active_fights.duplicate():
		FightHandler.end_fight(fight)

func _clear_active_fires() -> void:
	for fire in FireHandler.active_fires.duplicate():
		FireHandler.end_fire(fire)

func _clear_loose_items() -> void:
	if Global.ItemSpawner == null:
		return

	for child in Global.ItemSpawner.get_children():
		var item := child as Item
		if item == null or not is_instance_valid(item):
			continue
		item.destroy()

	Global.ItemSpawner.items.clear()
	LooseItemHandler.loose_items.clear()

func _clear_spawned_npcs() -> void:
	if Global.NPCSpawner == null:
		return

	NPCWorker.picked_up_npc = null
	NPCWorker.was_dragging = false
	JobHandler.workers.clear()

	for guest: NPCGuest in Global.NPCSpawner.guests.duplicate():
		if not is_instance_valid(guest):
			continue
		Global.NPCSpawner.on_guest_destroy(guest)
		guest.destroy()
	Global.NPCSpawner.guests.clear()

	for worker: NPCWorker in Global.NPCSpawner.workers.duplicate():
		if not is_instance_valid(worker):
			continue
		worker.destroy()
	Global.NPCSpawner.workers.clear()
	Global.NPCSpawner.worker_count_changed_signal.emit()

	for special: SpecialNPC in Global.NPCSpawner.special_npcs.duplicate():
		if not is_instance_valid(special):
			continue
		special.destroy()
	Global.NPCSpawner.special_npcs.clear()

	for child in Global.NPCSpawner.get_children():
		if child is HorseNPC or child is TraderWagon or child is NPCSheriff:
			child.queue_free()

func _clear_building() -> void:
	var rooms := _get_unique_rooms()
	if is_instance_valid(Building.infrastructure):
		Building.infrastructure.clear_all()

	Building.floors.clear()
	for room: RoomBase in rooms:
		if not is_instance_valid(room):
			continue
		room.destroy()

	MoneyHandler.location_money.clear()
	MoneyHandler.on_money_changed_signal.emit()
	Building.update_foreground_tiles()

func _get_unique_rooms() -> Array[RoomBase]:
	var rooms: Array[RoomBase] = []
	var seen := {}

	if not is_instance_valid(Building):
		return rooms

	for floor: Dictionary in Building.floors.values():
		for candidate in floor.values():
			var room := candidate as RoomBase
			if room == null or not is_instance_valid(room):
				continue
			var room_id := room.get_instance_id()
			if seen.has(room_id):
				continue
			seen[room_id] = true
			rooms.append(room)

	return rooms

func _serialize_vector2(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}

func _serialize_item(item: Item) -> Dictionary:
	var entry := {
		"item_type": int(item.itemType),
	}

	if item.itemType == Enum.Items.MONEY or item.money_amount > 0.0:
		entry["money_amount"] = item.money_amount
	if item.age > 0.0:
		entry["age"] = item.age
	if not is_equal_approx(item.aging_multiplier, 1.0):
		entry["aging_multiplier"] = item.aging_multiplier
	if item.itemType == Enum.Items.CRATE and item.crate_item_type >= 0:
		entry["crate_item_type"] = int(item.crate_item_type)
		entry["crate_item_amount"] = int(item.crate_item_amount)

	var trade_office_owner := item.trade_office_owner as RoomTradingOffice
	if is_instance_valid(trade_office_owner):
		entry["trade_office_owner"] = _serialize_room_index(Vector2i(trade_office_owner.x, trade_office_owner.y))

	return entry

func _serialize_room_state(room: RoomBase) -> Dictionary:
	if room is RoomWaterTower:
		var tower := room as RoomWaterTower
		return {
			"height": tower.data.height,
			"current_water": tower.current_water,
		}
	return {}

func _deserialize_vector2(value) -> Vector2:
	if value is not Dictionary:
		return Vector2.ZERO
	var data := value as Dictionary
	return Vector2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0))
	)

func _serialize_room_index(room_index: Vector2i) -> Dictionary:
	return {
		"x": room_index.x,
		"y": room_index.y,
	}

func _restore_item(entry: Dictionary) -> Item:
	if Global.ItemSpawner == null:
		return null

	var item_type := _sanitize_item_type(int(entry.get("item_type", Enum.Items.MONEY)))
	var item := Global.ItemSpawner.instantiate_item(item_type)
	if item == null:
		return null

	var trade_office_owner := _room_from_variant(entry.get("trade_office_owner", {})) as RoomTradingOffice
	if item_type == Enum.Items.CRATE and entry.has("crate_item_type"):
		item.crate_item_type = _sanitize_item_type(int(entry.get("crate_item_type", -1)))
		item.crate_item_amount = maxi(0, int(entry.get("crate_item_amount", 0)))
		item.trade_office_owner = trade_office_owner
		if item.crate_item_type >= 0 and item.crate_item_amount > 0:
			item.configure_trade_crate(item.crate_item_type, item.crate_item_amount, trade_office_owner)
		else:
			item.refresh_texture()

	if item_type == Enum.Items.MONEY:
		item.set_money_amount(float(entry.get("money_amount", item.money_amount)))

	item.age = float(entry.get("age", item.age))
	item.aging_multiplier = float(entry.get("aging_multiplier", item.aging_multiplier))

	if item.is_trade_crate() and is_instance_valid(trade_office_owner):
		trade_office_owner.register_delivery_crate(item)

	return item

func _get_room_resource_path(room: RoomBase) -> String:
	if room == null or room.data == null:
		return ""
	if not room.data.resource_path.is_empty():
		return room.data.resource_path
	if room is RoomWaterTower:
		return Building.room_data_water_tower.resource_path
	return ""

func _get_room_data_for_restore(entry: Dictionary) -> RoomData:
	var resource_path := String(entry.get("resource_path", ""))
	if resource_path.is_empty():
		return null

	var room_data := load(resource_path) as RoomData
	if room_data == null:
		Console.print_warning("Skipped missing room resource: %s" % resource_path)
		return null

	var state_variant = entry.get("state", {})
	if resource_path == Building.room_data_water_tower.resource_path and state_variant is Dictionary:
		var state := state_variant as Dictionary
		var saved_height := maxi(int(state.get("height", room_data.height)), Building.room_data_water_tower.height)
		if saved_height != room_data.height:
			room_data = room_data.duplicate()
			room_data.height = saved_height

	return room_data

func _restore_room_state(room: RoomBase, state_variant) -> void:
	if state_variant is not Dictionary:
		return

	var state := state_variant as Dictionary
	if room is RoomWaterTower:
		var tower := room as RoomWaterTower
		tower.restore_saved_state(
			maxi(int(state.get("height", tower.data.height)), Building.room_data_water_tower.height),
			float(state.get("current_water", tower.current_water))
		)

func _room_from_variant(value) -> RoomBase:
	if value is not Dictionary:
		return null
	var data := value as Dictionary
	return Building.get_room_from_index(Vector2i(
		int(data.get("x", 0)),
		int(data.get("y", 0))
	)) as RoomBase

func _sanitize_job(job: int) -> int:
	return job if job >= 0 and job < Enum.Jobs.keys().size() else Enum.Jobs.IDLE

func _sanitize_job_room_for_job(job_room: RoomBase, job: int) -> RoomBase:
	if job == Enum.Jobs.IDLE:
		return null
	if job_room == null or not is_instance_valid(job_room):
		return null
	if job_room.associated_job != job:
		return null
	return job_room

func _sanitize_item_type(item_type: int) -> int:
	return item_type if item_type >= 0 and item_type < Enum.Items.keys().size() else Enum.Items.MONEY

func _get_array(data: Dictionary, key: String) -> Array:
	var value = data.get(key, [])
	return value if value is Array else []

func _sort_grid_entries(a: Dictionary, b: Dictionary) -> bool:
	var ay := int(a.get("y", 0))
	var by := int(b.get("y", 0))
	if ay == by:
		return int(a.get("x", 0)) < int(b.get("x", 0))
	return ay < by

func _sort_storage_entries(a: Dictionary, b: Dictionary) -> bool:
	var room_a = a.get("room", {})
	var room_b = b.get("room", {})
	if room_a is Dictionary and room_b is Dictionary:
		var room_a_dict := room_a as Dictionary
		var room_b_dict := room_b as Dictionary
		var ay := int(room_a_dict.get("y", 0))
		var by := int(room_b_dict.get("y", 0))
		if ay != by:
			return ay < by
		var ax := int(room_a_dict.get("x", 0))
		var bx := int(room_b_dict.get("x", 0))
		if ax != bx:
			return ax < bx
	return int(a.get("slot", 0)) < int(b.get("slot", 0))
