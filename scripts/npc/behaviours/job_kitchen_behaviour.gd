extends Behaviour
class_name JobKitchenBehaviour

const _FUEL_ITEM_TYPES := [Enum.Items.WOOD, Enum.Items.COAL]
const _NO_WATER_ICON := preload("res://assets/sprites/ui/icon_no_water.png")
const ROOM_KITCHEN_SCRIPT := preload("res://scripts/room_kitchen.gd")

var kitchen = null

static var occupied_kitchens: Array = []

func start_loop() -> void:
	var assigned_kitchen: RoomKitchen = npc.current_job_room as RoomKitchen if is_instance_valid(npc.current_job_room) and npc.current_job_room is RoomKitchen else null
	if assigned_kitchen != null and not occupied_kitchens.has(assigned_kitchen):
		kitchen = assigned_kitchen
		occupied_kitchens.append(kitchen)
		kitchen.worker = npc
		if not kitchen.on_destroy_signal.is_connected(_change_to_idle):
			kitchen.on_destroy_signal.connect(_change_to_idle)
	else:
		kitchen = try_get_room_if_not_occupied(data, ROOM_KITCHEN_SCRIPT, occupied_kitchens)
	if kitchen != null:
		npc.current_job_room = kitchen

func loop() -> void:
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	await move(kitchen.get_random_floor_position())

	while true:
		if kitchen.has_pending_requests() and kitchen.has_available_soup():
			npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
			await move(kitchen)
			_narrative = ["Serving soup...", "Ladling out bowls...", "Handing over hot soup..."].pick_random()
			await progress(0.75)
			kitchen.fulfill_next_request()
			var sale_price := roundi(kitchen.get_sale_price() * npc.Traits.get_sale_multiplier())
			MoneyHandler.earn_animated(sale_price, kitchen.get_center_position(), Vector2i(kitchen.x, kitchen.y), "Soup Sales")
			continue

		if not kitchen.water_loaded:
			await _load_water()
			continue

		if not kitchen.fuel_loaded:
			await _load_fuel()
			continue

		if kitchen.can_cook_batch():
			await _cook_batch()
			continue

		npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
		await move(kitchen)
		_narrative = ["Waiting for orders...", "Keeping the pot warm...", "Ready to cook..."].pick_random()
		await pause(1.0)

func stop_loop() -> BehaviourSaveData:
	if kitchen != null:
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	occupied_kitchens.erase(kitchen)
	if is_instance_valid(kitchen):
		kitchen.worker = null

	var save := BehaviourSaveData.new(get_script())
	save.room = kitchen
	return save

func _load_water() -> void:
	var got_water := false
	if kitchen.uses_infrastructure_layer(&"water"):
		npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
		got_water = await try_fetch_from_tower(kitchen.get_center_floor_position(), kitchen)
	if not got_water:
		_narrative = ["Fetching water...", "Filling a bucket...", "Getting water for the soup..."].pick_random()
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		await fetch_item(Enum.Items.WATER_BUCKET)
		if not npc.Item.is_item(Enum.Items.WATER_BUCKET):
			RoomStatusHandler.notify(kitchen, "no water", Color.ORANGE, _NO_WATER_ICON)
			await pause(2.0)
			return

		npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
		await move(kitchen)
		if not is_instance_valid(kitchen):
			return
		var water_item := npc.Item.drop_current()
		if is_instance_valid(water_item):
			water_item.destroy()

	kitchen.load_water()

func _load_fuel() -> void:
	if not _has_carried_fuel():
		_narrative = ["Fetching fuel...", "Looking for wood or coal...", "Fetching wood for the stove..."].pick_random()
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		await _fetch_fuel()
		if not _has_carried_fuel():
			RoomStatusHandler.notify(kitchen, "no fuel", Color.ORANGE, Item.get_info(Enum.Items.WOOD).Tex)
			await pause(2.0)
			return

	if not is_instance_valid(kitchen):
		return

	_narrative = ["Stoking the kitchen fire...", "Loading the stove...", "Feeding the burner..."].pick_random()
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	await move(kitchen)
	if not is_instance_valid(kitchen):
		return

	await progress(ROOM_KITCHEN_SCRIPT.LOAD_DURATION)
	if not is_instance_valid(kitchen) or not _has_carried_fuel():
		return

	_consume_carried_fuel()
	kitchen.load_fuel()

func _cook_batch() -> void:
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)
	await move(kitchen)
	_narrative = ["Cooking soup...", "Tending the pot...", "Stirring the broth..."].pick_random()
	await progress(ROOM_KITCHEN_SCRIPT.COOK_DURATION)
	if not is_instance_valid(kitchen):
		return
	kitchen.cook_batch()

func _has_carried_fuel() -> bool:
	return npc != null \
	and npc.Item != null \
	and npc.Item.current_item != null \
	and Item.is_fuel_item(npc.Item.current_item.itemType)

func _fetch_fuel() -> void:
	var preferred_fuel_type := _find_best_available_fuel_type()
	if preferred_fuel_type >= 0:
		await fetch_item(preferred_fuel_type)
		return
	await fetch_item(Enum.Items.WOOD)

func _find_best_available_fuel_type() -> int:
	var best_type := -1
	var best_distance := INF

	for fuel_type in _FUEL_ITEM_TYPES:
		var loose_item: Item = LooseItemHandler.get_closest_to(npc.global_position, fuel_type)
		if loose_item != null:
			var loose_distance := npc.global_position.distance_squared_to(loose_item.global_position)
			if LooseItemHandler.debug_fetch:
				LooseItemHandler.log_fetch(npc, "kitchen fuel candidate: loose %s %s" % [Enum.Items.keys()[fuel_type], LooseItemHandler.describe_position(npc.global_position, loose_item.global_position)])
			if loose_distance < best_distance:
				best_distance = loose_distance
				best_type = fuel_type

		for storage: RoomStorage in get_all_rooms_of_type_ordered_by_distance(RoomStorage):
			if not storage.has(fuel_type):
				continue
			var storage_distance := npc.global_position.distance_squared_to(storage.get_center_floor_position())
			if LooseItemHandler.debug_fetch:
				LooseItemHandler.log_fetch(npc, "kitchen fuel candidate: storage %s %s" % [Enum.Items.keys()[fuel_type], LooseItemHandler.describe_position(npc.global_position, storage.get_center_floor_position())])
			if storage_distance < best_distance:
				best_distance = storage_distance
				best_type = fuel_type
			break

	if LooseItemHandler.debug_fetch:
		LooseItemHandler.log_fetch(npc, "kitchen picked fuel type: %s" % (Enum.Items.keys()[best_type] if best_type >= 0 else "none (falls back to WOOD)"))
	return best_type

func _consume_carried_fuel() -> void:
	npc.Item.current_item.destroy()
	npc.Item.current_item = null
