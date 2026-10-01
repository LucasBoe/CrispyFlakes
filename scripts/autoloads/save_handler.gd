extends Node

const SAVE_PATH := "user://simple_save.json"
const SAVE_VERSION := 6

var _pending_load := false
var _pending_save_path := SAVE_PATH
const DAYS_PER_MONTH := 30.0
var played_seconds := 0.0
var _saving := false
var save_directory := "user://"
var active_save_path := ""

func _physics_process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == "res://scenes/mainscene.tscn":
		played_seconds += delta

func _ready() -> void:
	Console.add_command("save", console_save, 0, 0, "Saves placed rooms plus worker and guest positions.")
	Console.add_command("load", console_load, 0, 0, "Loads the simple room and NPC save file.")

func has_save() -> bool:
	return not get_save_paths().is_empty()

func get_save_paths() -> Array[String]:
	var paths: Array[String] = []
	var legacy_path := save_directory.path_join("simple_save.json")
	if FileAccess.file_exists(legacy_path):
		paths.append(legacy_path)
	var directory := DirAccess.open(save_directory)
	if directory != null:
		directory.list_dir_begin()
		var file_name := directory.get_next()
		while not file_name.is_empty():
			if not directory.current_is_dir() and file_name.begins_with("save_") and file_name.ends_with(".json"):
				paths.append(save_directory.path_join(file_name))
			file_name = directory.get_next()
		directory.list_dir_end()
	var save_times := {}
	for path in paths:
		save_times[path] = get_save_info(path).get("saved_at_unix", FileAccess.get_modified_time(path))
	paths.sort_custom(func(a: String, b: String) -> bool:
		var a_time: float = save_times[a]
		var b_time: float = save_times[b]
		return a_time > b_time if a_time != b_time else a > b
	)
	return paths

func get_continue_path() -> String:
	var paths := get_save_paths()
	return paths[0] if not paths.is_empty() else ""

func get_save_numbers() -> Dictionary:
	var numbers := {}
	var paths := get_save_paths()
	paths.sort()
	for path in paths:
		var suffix := path.get_file().get_basename().trim_prefix("save_")
		if suffix.is_valid_int() and int(suffix) > 0:
			numbers[path] = int(suffix)
	# Preserve old saves without renaming them or colliding with numbered slots.
	for path in paths:
		if numbers.has(path):
			continue
		var number := 1
		while number in numbers.values():
			number += 1
		numbers[path] = number
	return numbers

func get_new_save_path() -> String:
	var number := 1
	for existing_number: int in get_save_numbers().values():
		number = maxi(number, existing_number + 1)
	return save_directory.path_join("save_%04d.json" % number)

func get_save_number(path: String) -> int:
	var suffix := path.get_file().get_basename().trim_prefix("save_")
	if suffix.is_valid_int():
		return int(suffix)
	return int(get_save_numbers().get(path, 1))

func get_save_info(path: String = "") -> Dictionary:
	if path.is_empty():
		path = get_continue_path()
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or json.data is not Dictionary:
		return {}
	var data: Dictionary = json.data
	var scenario_id := str(data.get("scenario_id", ""))
	var scenario := ScenarioHandler.get_scenario(scenario_id)
	var mode := "Tutorial" if scenario_id.is_empty() else "Sandbox"
	if scenario != null and scenario.is_campaign:
		mode = "Campaign"
	var saved_at := str(data.get("saved_at", ""))
	var date: Dictionary
	if saved_at.is_empty():
		var local_timestamp := FileAccess.get_modified_time(path) + int(Time.get_time_zone_from_system().bias) * 60
		date = Time.get_datetime_dict_from_unix_time(local_timestamp)
	else:
		date = Time.get_datetime_dict_from_datetime_string(saved_at, false)
	var cash := float(data.get("money_free_pool", 0.0))
	for entry: Dictionary in data.get("money_location_money", []):
		cash += float(entry.get("amount", 0.0))
	return {
		"saved_at_unix": float(data.get("saved_at_unix", FileAccess.get_modified_time(path))),
		"game_mode": str(data.get("game_mode", mode)),
		"scenario_name": str(data.get("scenario_name", scenario.display_name if scenario != null and scenario.is_campaign else "")),
		"saloon_name": str(data.get("saloon_name", "")),
		"date": "%02d.%02d.%04d" % [date.day, date.month, date.year],
		"timestamp": "%02d.%02d.%04d · %02d:%02d" % [date.day, date.month, date.year, date.hour, date.minute],
		"months_played": floori(float(data.played_seconds) / (Global.DAY_DURATION * DAYS_PER_MONTH)) if data.has("played_seconds") else -1,
		"cash_owned": cash,
		"worker_count": _get_array(data, "workers").size(),
		"preview_path": str(data.get("preview_path", "")),
	}

func flag_pending_load(save_path: String = "") -> void:
	_pending_load = true
	_pending_save_path = get_continue_path() if save_path.is_empty() else save_path

func has_pending_load() -> bool:
	return _pending_load

func load_pending() -> void:
	_pending_load = false
	console_load(_pending_save_path)

func console_save(save_path: String = "") -> void:
	if save_path.is_empty():
		save_path = active_save_path if not active_save_path.is_empty() else get_new_save_path()
	var error := await save_game(save_path)
	if error != OK:
		Console.print_error("Could not save game: %s." % error_string(error))

func save_game(save_path: String) -> Error:
	if _saving:
		return ERR_BUSY
	_saving = true
	TimeHandler.push_pause_lock(self)
	var preview_path := await _capture_save_preview(save_path)
	var rooms := _serialize_rooms()
	var water_pipes := _serialize_water_pipes()
	var electricity_tiles := _serialize_electricity_tiles()
	var stored_items := _serialize_stored_items()
	var loose_items := _serialize_loose_items()
	var workers := _serialize_workers()
	var guests := _serialize_guests()
	var cages := _serialize_cages()
	var equipment := _serialize_equipment()
	var scenario := _serialize_scenario()
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"played_seconds": played_seconds,
		"preview_path": preview_path,
		"saloon_name": (Building.get_node("SaloonSign") as BuildingSign).saloon_name,
		"game_mode": "Tutorial" if ScenarioHandler.current_scenario == null else ("Campaign" if ScenarioHandler.current_scenario.is_campaign else "Sandbox"),
		"scenario_name": ScenarioHandler.current_scenario.display_name if ScenarioHandler.current_scenario != null and ScenarioHandler.current_scenario.is_campaign else "",
		"rooms": rooms,
		"water_pipes": water_pipes,
		"electricity_tiles": electricity_tiles,
		"stored_items": stored_items,
		"loose_items": loose_items,
		"workers": workers,
		"guests": guests,
		"cages": cages,
		"equipment": equipment,
		"money_free_pool": MoneyHandler.free_pool,
		"money_location_money": _serialize_money_locations(),
		"guest_type_reputation": _serialize_type_reputation(),
		"scenario_id": scenario.get("scenario_id", ""),
		"scenario_goal_progress": scenario.get("scenario_goal_progress", {}),
		"scenario_win_state": scenario.get("scenario_win_state", ScenarioHandler.WinState.NONE),
		"scenario_fired_beats": scenario.get("scenario_fired_beats", []),
	}

	TimeHandler.pop_pause_lock(self)
	_saving = false
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	error = DirAccess.rename_absolute(temporary_path, save_path)
	if error != OK:
		return error
	active_save_path = save_path
	Console.print_line("Saved %d rooms, %d pipes, %d electricity tiles, %d stored items, %d loose items, %d workers, %d guests, %d cages, %d equipment to %s." % [
		rooms.size(),
		water_pipes.size(),
		electricity_tiles.size(),
		stored_items.size(),
		loose_items.size(),
		workers.size(),
		guests.size(),
		cages.size(),
		equipment.size(),
		ProjectSettings.globalize_path(save_path),
	])
	return OK

func _capture_save_preview(save_path: String) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var ui := Global.UI
	var ui_visible := is_instance_valid(ui) and ui.visible
	var console_visible: bool = Console.control.visible
	if is_instance_valid(ui):
		ui.hide()
	Console.control.hide()
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	if is_instance_valid(ui):
		ui.visible = ui_visible
	Console.control.visible = console_visible
	var preview_path := save_path.get_basename() + ".png"
	if screenshot == null or screenshot.is_empty() or screenshot.save_png(preview_path) != OK:
		return ""
	return preview_path

func console_load(save_path: String = "") -> void:
	if save_path.is_empty():
		save_path = get_continue_path()
	if not FileAccess.file_exists(save_path):
		Console.print_error("No save file found at %s." % ProjectSettings.globalize_path(save_path))
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		Console.print_error("Failed to open %s for reading." % ProjectSettings.globalize_path(save_path))
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or parsed is not Dictionary:
		Console.print_error("Save file is not valid JSON.")
		return

	var save_data := parsed as Dictionary
	await _apply_save(save_data)
	active_save_path = save_path

	var room_count := _get_array(save_data, "rooms").size()
	var pipe_count := _get_array(save_data, "water_pipes").size()
	var electricity_count := _get_array(save_data, "electricity_tiles").size()
	var stored_item_count := _get_array(save_data, "stored_items").size()
	var loose_item_count := _get_array(save_data, "loose_items").size()
	var worker_count := _get_array(save_data, "workers").size()
	var guest_count := _get_array(save_data, "guests").size()
	var cage_count := _get_array(save_data, "cages").size()
	var equipment_count := _get_array(save_data, "equipment").size()
	Console.print_line("Loaded %d rooms, %d pipes, %d electricity tiles, %d stored items, %d loose items, %d workers, %d guests, %d cages, %d equipment from %s." % [
		room_count,
		pipe_count,
		electricity_count,
		stored_item_count,
		loose_item_count,
		worker_count,
		guest_count,
		cage_count,
		equipment_count,
		ProjectSettings.globalize_path(save_path),
	])

func _apply_save(save_data: Dictionary) -> void:
	played_seconds = float(save_data.get("played_seconds", 0.0))
	if int(save_data.get("version", 0)) < SAVE_VERSION:
		save_data = _backfill_save_data(save_data)

	TimeHandler.push_pause_lock(self)
	FeatureGateHandler.set_enabled(FeatureGateHandler.Feature.GUEST_AUTO_SPAWN, false)

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
	_restore_equipment(_get_array(save_data, "equipment"))

	await get_tree().process_frame

	# Cages need their shaft's ElevatorShaftController to already exist - that's built off the
	# room-created signals emitted during _restore_rooms above, which ElevatorHandler handles
	# deferred (see elevator_handler.gd), so waiting for the process_frame above first is required.
	_restore_cages(_get_array(save_data, "cages"))

	_restore_money_locations(_get_array(save_data, "money_location_money"))
	MoneyHandler.free_pool = float(save_data.get("money_free_pool", MoneyHandler.free_pool))
	MoneyHandler.on_money_changed_signal.emit()
	_restore_type_reputation(save_data.get("guest_type_reputation", {}))
	_apply_scenario_restore(save_data)
	(Building.get_node("SaloonSign") as BuildingSign).set_saloon_name(str(save_data.get("saloon_name", "My Saloon")))

	FeatureGateHandler.set_enabled(FeatureGateHandler.Feature.GUEST_AUTO_SPAWN, true)
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

	for worker: NPCWorker in Global.NPCSpawner.get_live_workers():
		if not is_instance_valid(worker):
			continue

		var job := _sanitize_job(int(worker.current_job))
		var job_room := _sanitize_job_room_for_job(worker.current_job_room, job)
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

	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
		guests.append({
			"name": guest.character_name,
			"position": _serialize_vector2(guest.global_position),
		})

	return guests

func _serialize_cages() -> Array[Dictionary]:
	var cages: Array[Dictionary] = []
	for controller in ElevatorHandler._controllers:
		if controller.rooms.is_empty():
			continue
		var x: int = controller.rooms[0].x
		for cage in controller.cages:
			if not is_instance_valid(cage):
				continue
			cages.append(_serialize_room_index(Vector2i(x, cage.current_floor_y)))

	cages.sort_custom(func(a: Dictionary, b: Dictionary): return _sort_grid_entries(a, b))
	return cages

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

func _serialize_equipment() -> Array[Dictionary]:
	var equipment: Array[Dictionary] = []
	for inst: EquipmentInstance in EquipmentInventory.instances:
		if inst.data == null or inst.data.resource_path.is_empty():
			continue
		var entry := {
			"resource_path": inst.data.resource_path,
		}
		var equipped_worker := inst.equipped_by as NPCWorker
		if is_instance_valid(equipped_worker):
			entry["equipped_by"] = equipped_worker.character_name
		equipment.append(entry)
	return equipment

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

func _serialize_type_reputation() -> Dictionary:
	var reputation := {}
	for body_type in Global.NPCSpawner.type_reputation.keys():
		reputation[str(body_type)] = Global.NPCSpawner.type_reputation[body_type]
	return reputation

func _restore_type_reputation(value) -> void:
	Global.NPCSpawner.type_reputation.clear()
	if value is not Dictionary:
		return
	for key in value.keys():
		Global.NPCSpawner.type_reputation[int(key)] = float(value[key])

func _restore_cages(entries: Array) -> void:
	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue
		var entry := entry_variant as Dictionary
		ElevatorHandler.place_cage(int(entry.get("x", 0)), int(entry.get("y", 0)))

func _restore_equipment(entries: Array) -> void:
	EquipmentInventory.instances.clear()
	if entries.is_empty():
		return

	var workers_by_name: Dictionary = {}
	if Global.NPCSpawner != null:
		for worker: NPCWorker in Global.NPCSpawner.get_live_workers():
			workers_by_name[worker.character_name] = worker

	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue

		var entry := entry_variant as Dictionary
		var resource_path := String(entry.get("resource_path", ""))
		if resource_path.is_empty():
			continue

		var data := load(resource_path) as EquipmentData
		if data == null:
			Console.print_warning("Skipped missing equipment resource: %s" % resource_path)
			continue

		var inst := EquipmentInstance.new()
		inst.data = data
		var owner_name := String(entry.get("equipped_by", ""))
		if not owner_name.is_empty() and workers_by_name.has(owner_name):
			inst.equipped_by = workers_by_name[owner_name]
		EquipmentInventory.instances.append(inst)

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

func end_session() -> void:
	TimeHandler.push_pause_lock(self)
	FeatureGateHandler.set_enabled(FeatureGateHandler.Feature.GUEST_AUTO_SPAWN, false)
	await StartupCoordinator.cancel()
	ScenarioHandler.end_session()
	TutorialHandler.clear_quests()
	PlacementHandler.stop_building()
	RoomStatusHandler.enabled = false
	_clear_active_fights()
	_clear_active_fires()
	_clear_spawned_npcs()
	# Let NPC destruction release held items and room reservations first.
	await get_tree().process_frame
	_clear_loose_items()
	_clear_building()
	for dirt in DirtHandler.dirt_instances.duplicate():
		DirtHandler.clean_dirt(dirt)
	for puddle in PuddleHandler.puddle_instances.duplicate():
		PuddleHandler.clean_puddle(puddle)
	UiNotifications.clear_all()
	AnimatedUIResources.clear_all()
	EquipmentInventory.instances.clear()
	BountyHandler.npc_bounties.clear()
	BountyHandler.npc_fight_fines.clear()
	BountyHandler.npc_fine_reasons.clear()
	BountyHandler.active_looks.clear()
	HoverHandler.currently_hovered = null
	HoverHandler.previously_hovered = null
	HoverHandler.worker_ui_active = false
	Global.NPCSpawner.next_guest_progression = 1.0
	Global.NPCSpawner.next_special_encounter_progression = 0.0
	Global.NPCSpawner.type_reputation.clear()
	Building.visible = false
	await get_tree().process_frame
	TimeHandler.pop_pause_lock(self)

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

	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
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
		if child.is_queued_for_deletion():
			continue
		if child is NPC:
			child.destroy()
		else:
			child.queue_free()

func _clear_building() -> void:
	var rooms := _get_unique_rooms()
	if is_instance_valid(Building.infrastructure):
		Building.infrastructure.clear_all()
	ElevatorHandler.clear_all_cages() # cages aren't rooms, so the loop below never reaches them

	Building.floors.clear()
	for room: RoomBase in rooms:
		if not is_instance_valid(room):
			continue
		GlobalEventHandler.on_room_deleted_signal.emit(room)
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

func _sanitize_job_room_for_job(job_room: Variant, job: int) -> RoomBase:
	if job == Enum.Jobs.IDLE:
		return null
	if job_room == null or not is_instance_valid(job_room):
		return null
	if job_room is not RoomBase:
		return null
	var room := job_room as RoomBase
	if room.associated_job != job:
		return null
	return room

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

func _serialize_money_locations() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for loc: Vector2i in MoneyHandler.location_money.keys():
		entries.append({
			"x": loc.x,
			"y": loc.y,
			"amount": MoneyHandler.location_money[loc],
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return _sort_grid_entries(a, b))
	return entries

func _restore_money_locations(entries: Array) -> void:
	MoneyHandler.location_money.clear()
	for entry_variant in entries:
		if entry_variant is not Dictionary:
			continue
		var entry := entry_variant as Dictionary
		var loc := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		MoneyHandler.location_money[loc] = float(entry.get("amount", 0.0))

func _serialize_scenario() -> Dictionary:
	if ScenarioHandler.current_scenario == null:
		return {
			"scenario_id": "",
			"scenario_goal_progress": {},
			"scenario_win_state": ScenarioHandler.WinState.NONE,
			"scenario_fired_beats": [],
		}

	var goal_progress := {}
	for key in ScenarioHandler.get_registered_quest_keys():
		var quest := TutorialHandler.get_quest(key)
		if quest == null:
			goal_progress[key] = {"phase": TutorialHandler.TutorialPhase.DONE, "metadata": {}}
			continue
		goal_progress[key] = {"phase": quest.phase, "metadata": quest.metadata}

	return {
		"scenario_id": ScenarioHandler.current_scenario.scenario_id,
		"scenario_goal_progress": goal_progress,
		"scenario_win_state": ScenarioHandler.win_state,
		"scenario_fired_beats": ScenarioHandler.get_fired_beat_ids(),
	}

func _apply_scenario_restore(save_data: Dictionary) -> void:
	var scenario_id := String(save_data.get("scenario_id", ""))
	if scenario_id.is_empty():
		ScenarioHandler.current_scenario = null
		ScenarioHandler.win_state = ScenarioHandler.WinState.NONE
		Balancing.GUEST_SPAWN_BASE_RATE = Balancing.GUEST_SPAWN_BASE_RATE_DEFAULT
		return

	var scenario := ScenarioHandler.get_scenario(scenario_id)
	if scenario == null:
		Console.print_warning("Skipped missing scenario: %s" % scenario_id)
		return

	var saved_win_state := int(save_data.get("scenario_win_state", ScenarioHandler.WinState.NONE))
	ScenarioHandler.resume_scenario(scenario, saved_win_state)

	var goal_progress_variant = save_data.get("scenario_goal_progress", {})
	var goal_progress: Dictionary = goal_progress_variant if goal_progress_variant is Dictionary else {}

	if scenario is CampaignScenarioData:
		for goal: ScenarioGoalDefinition in (scenario as CampaignScenarioData).goal_definitions:
			TutorialHandler.create_quest(goal.key, goal.text, [], goal.reward_money, goal.reward_text, TutorialHandler.TutorialPhase.ACTIVE)
			var entry_variant = goal_progress.get(goal.key, null)
			if entry_variant is Dictionary:
				var entry := entry_variant as Dictionary
				TutorialHandler.restore_quest_state(goal.key, int(entry.get("phase", TutorialHandler.TutorialPhase.ACTIVE)), entry.get("metadata", {}))

	for beat_id in _get_array(save_data, "scenario_fired_beats"):
		ScenarioHandler.mark_beat_fired(str(beat_id))

func _backfill_save_data(save_data: Dictionary) -> Dictionary:
	if not save_data.has("scenario_id"):
		save_data["scenario_id"] = ""
	if not save_data.has("scenario_goal_progress"):
		save_data["scenario_goal_progress"] = {}
	if not save_data.has("scenario_win_state"):
		save_data["scenario_win_state"] = ScenarioHandler.WinState.NONE
	if not save_data.has("scenario_fired_beats"):
		save_data["scenario_fired_beats"] = []
	if not save_data.has("money_free_pool"):
		save_data["money_free_pool"] = MoneyHandler.free_pool
	if not save_data.has("money_location_money"):
		save_data["money_location_money"] = []
	return save_data
