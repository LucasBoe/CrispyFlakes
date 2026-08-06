extends Behaviour
class_name JobFireplaceKeeperBehaviour

const IDLE_WAIT_DURATION := 2.0
const POKE_FIRE_DURATION := 1.0
const _FUEL_ITEM_TYPES := [Enum.Items.WOOD, Enum.Items.COAL]

static var occupied_fireplaces: Array = []

var fireplace: RoomFireplace = null


func loop():
	while true:
		var task := _find_next_task()
		if task.is_empty():
			var home_fireplace := _get_home_fireplace()
			npc.current_job_room = home_fireplace
			_narrative = ["Watching the fireplaces...", "Waiting for the next log...", "Keeping an eye on the embers..."].pick_random()
			if is_instance_valid(home_fireplace) and npc.global_position.distance_to(home_fireplace.get_floor_position()) > 20.0:
				await move(home_fireplace.get_floor_position())
			await pause(IDLE_WAIT_DURATION)
			continue

		var target_fireplace := task.get("fireplace", null) as RoomFireplace
		if not is_instance_valid(target_fireplace):
			continue

		_claim_fireplace(target_fireplace)
		npc.current_job_room = target_fireplace

		match String(task.get("type", "")):
			"light_from_stockpile":
				await _light_from_stockpile(target_fireplace)
			"light_with_carried":
				await _light_with_carried_fuel(target_fireplace)
			"stock_carried":
				await _stock_carried_fuel(target_fireplace)
			"poke":
				await _poke_fire(target_fireplace)
			"relocate_loose_fuel":
				await _relocate_loose_fuel(task.get("item", null) as Item, target_fireplace)
			"fetch_and_deliver":
				await _fetch_and_deliver_fuel(target_fireplace)

		_release_fireplace()


func stop_loop() -> BehaviourSaveData:
	_release_fireplace()
	var home_fireplace := _get_home_fireplace()
	if _has_carried_fuel():
		var dropped := npc.Item.drop_current()
		if dropped != null and is_instance_valid(home_fireplace):
			dropped.global_position = home_fireplace.get_stockpile_drop_position()

	var save := super.stop_loop()
	save.room = home_fireplace
	return save


func _find_next_task() -> Dictionary:
	_cleanup_occupied_fireplaces()

	if _has_carried_fuel():
		var unlit_with_carried := _find_fireplace(func(candidate: RoomFireplace): return not candidate.is_heating())
		if unlit_with_carried != null:
			return {"type": "light_with_carried", "fireplace": unlit_with_carried}

	var unlit_with_stockpile := _find_fireplace(func(candidate: RoomFireplace): return not candidate.is_heating() and candidate.has_stockpiled_fuel())
	if unlit_with_stockpile != null:
		return {"type": "light_from_stockpile", "fireplace": unlit_with_stockpile}

	var poke_target := _find_fireplace(func(candidate: RoomFireplace): return candidate.needs_poking())
	if poke_target != null:
		return {"type": "poke", "fireplace": poke_target}

	if _has_carried_fuel():
		var stock_carried_target := _find_best_fireplace_for_fuel_delivery()
		if stock_carried_target != null:
			return {"type": "stock_carried", "fireplace": stock_carried_target}

	var loose_fuel := _find_loose_fuel_not_stockpiled()
	if loose_fuel != null:
		var loose_target := _find_best_fireplace_for_fuel_delivery()
		if loose_target != null:
			return {"type": "relocate_loose_fuel", "fireplace": loose_target, "item": loose_fuel}

	var fetch_target := _find_fireplace(func(candidate: RoomFireplace): return not candidate.is_heating() or candidate.needs_stockpile())
	if fetch_target != null:
		return {"type": "fetch_and_deliver", "fireplace": fetch_target}

	return {}


func _light_from_stockpile(target_fireplace: RoomFireplace) -> void:
	if not is_instance_valid(target_fireplace):
		return

	_narrative = ["Lighting the fireplace...", "Getting the hearth going...", "Bringing the fire back..."].pick_random()
	await move(target_fireplace.get_floor_position())
	if not is_instance_valid(target_fireplace) or target_fireplace.is_heating():
		return

	await progress(RoomStove.REFUEL_DURATION)
	if not is_instance_valid(target_fireplace) or target_fireplace.is_heating():
		return

	var fuel_item_type := target_fireplace.consume_stockpiled_fuel_type()
	if fuel_item_type >= 0:
		target_fireplace.refuel(fuel_item_type)


func _light_with_carried_fuel(target_fireplace: RoomFireplace) -> void:
	if not is_instance_valid(target_fireplace):
		return
	if not _has_carried_fuel():
		return

	_narrative = ["Lighting the fireplace...", "Feeding the hearth...", "Getting the fire started..."].pick_random()
	await move(target_fireplace.get_floor_position())
	if not is_instance_valid(target_fireplace):
		return

	await progress(RoomStove.REFUEL_DURATION)
	if not is_instance_valid(target_fireplace):
		return

	if not target_fireplace.is_heating():
		var fuel_item_type := _consume_carried_fuel()
		target_fireplace.refuel(fuel_item_type)
		return

	await _stock_carried_fuel(target_fireplace)


func _stock_carried_fuel(target_fireplace: RoomFireplace) -> void:
	if not is_instance_valid(target_fireplace):
		return
	if not _has_carried_fuel():
		return

	_narrative = ["Stacking fuel...", "Dropping fuel by the hearth...", "Stocking the fireplace..."].pick_random()
	await move(target_fireplace.get_floor_position())
	if not is_instance_valid(target_fireplace):
		return

	var dropped := npc.Item.drop_current()
	if dropped == null:
		return

	dropped.global_position = target_fireplace.get_stockpile_drop_position()
	dropped.global_rotation = 0.0
	dropped.scale = Vector2.ONE


func _poke_fire(target_fireplace: RoomFireplace) -> void:
	if not is_instance_valid(target_fireplace) or not target_fireplace.is_heating():
		return

	_narrative = ["Poking the fire...", "Working the embers...", "Keeping the flames lively..."].pick_random()
	await move(target_fireplace.get_floor_position())
	if not is_instance_valid(target_fireplace) or not target_fireplace.is_heating():
		return

	await progress(POKE_FIRE_DURATION)
	if not is_instance_valid(target_fireplace):
		return

	target_fireplace.poke_fire()


func _relocate_loose_fuel(fuel_item: Item, target_fireplace: RoomFireplace) -> void:
	if fuel_item == null or not is_instance_valid(fuel_item) or not is_instance_valid(target_fireplace):
		return

	_narrative = ["Collecting loose fuel...", "Gathering up spare fuel...", "Bringing fuel to the fireplaces..."].pick_random()
	await move(fuel_item)
	if not is_instance_valid(fuel_item):
		return

	npc.Item.pick_up(fuel_item)
	if not _has_carried_fuel():
		return

	if not target_fireplace.is_heating():
		await _light_with_carried_fuel(target_fireplace)
		return

	await _stock_carried_fuel(target_fireplace)


func _fetch_and_deliver_fuel(target_fireplace: RoomFireplace) -> void:
	if not is_instance_valid(target_fireplace):
		return

	_narrative = ["Fetching fuel...", "Looking for more wood or coal...", "Bringing in fuel..."].pick_random()
	await _fetch_fuel()
	if not _has_carried_fuel():
		return

	if not target_fireplace.is_heating():
		await _light_with_carried_fuel(target_fireplace)
		return

	await _stock_carried_fuel(target_fireplace)


func _find_fireplace(filter_fn: Callable) -> RoomFireplace:
	for candidate: RoomFireplace in _get_fireplaces_ordered_by_distance():
		if occupied_fireplaces.has(candidate):
			continue
		if not filter_fn.is_null() and not filter_fn.call(candidate):
			continue
		return candidate
	return null


func _find_best_fireplace_for_fuel_delivery() -> RoomFireplace:
	var fireplaces := _get_fireplaces_ordered_by_distance()
	if fireplaces.is_empty():
		return null

	var unlit := fireplaces.filter(func(candidate: RoomFireplace): return not occupied_fireplaces.has(candidate) and not candidate.is_heating())
	if not unlit.is_empty():
		return unlit[0]

	var needs_stock := fireplaces.filter(func(candidate: RoomFireplace): return not occupied_fireplaces.has(candidate) and candidate.needs_stockpile())
	if not needs_stock.is_empty():
		return needs_stock[0]

	for candidate: RoomFireplace in fireplaces:
		if not occupied_fireplaces.has(candidate):
			return candidate
	return null


func _find_loose_fuel_not_stockpiled() -> Item:
	var fireplaces := _get_fireplaces_ordered_by_distance()
	var closest: Item = null
	var best_distance := INF
	for fuel_type in _FUEL_ITEM_TYPES:
		var fuel_items := LooseItemHandler.loose_items.get(fuel_type, []) as Array
		if fuel_items == null:
			continue

		for candidate in fuel_items:
			var item := candidate as Item
			if item == null or not is_instance_valid(item):
				continue

			var source_room := Building.query.closest_on_position_floor(RoomBase, item.global_position) as RoomBase
			if source_room != null and not npc.Navigation.is_room_reachable(source_room):
				continue

			var already_stockpiled := false
			for target_fireplace: RoomFireplace in fireplaces:
				if target_fireplace.is_loose_fuel_stockpiled(item):
					already_stockpiled = true
					break
			if already_stockpiled:
				continue

			var distance := npc.global_position.distance_squared_to(item.global_position)
			if distance < best_distance:
				best_distance = distance
				closest = item

	return closest


func _get_fireplaces_ordered_by_distance() -> Array[RoomFireplace]:
	var fireplaces: Array[RoomFireplace] = []
	var seen_room_ids := {}
	for candidate in get_all_rooms_of_type_ordered_by_distance(RoomFireplace):
		var fireplace_candidate := candidate as RoomFireplace
		if fireplace_candidate == null or not is_instance_valid(fireplace_candidate):
			continue
		var room_id := fireplace_candidate.get_instance_id()
		if seen_room_ids.has(room_id):
			continue
		seen_room_ids[room_id] = true
		fireplaces.append(fireplace_candidate)
	return fireplaces


func _get_home_fireplace() -> RoomFireplace:
	if is_instance_valid(fireplace):
		return fireplace
	if is_instance_valid(npc.current_job_room) and npc.current_job_room is RoomFireplace:
		return npc.current_job_room as RoomFireplace
	if data != null and is_instance_valid(data.room) and data.room is RoomFireplace:
		return data.room as RoomFireplace
	var fireplaces := _get_fireplaces_ordered_by_distance()
	return null if fireplaces.is_empty() else fireplaces[0]


func _claim_fireplace(target_fireplace: RoomFireplace) -> void:
	fireplace = target_fireplace
	if not occupied_fireplaces.has(target_fireplace):
		occupied_fireplaces.append(target_fireplace)
	target_fireplace.worker = npc


func _release_fireplace() -> void:
	if is_instance_valid(fireplace) and fireplace.worker == npc:
		fireplace.worker = null
	occupied_fireplaces.erase(fireplace)
	fireplace = null


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
			if loose_distance < best_distance:
				best_distance = loose_distance
				best_type = fuel_type

		for storage: RoomStorage in get_all_rooms_of_type_ordered_by_distance(RoomStorage):
			if not storage.has(fuel_type):
				continue

			var storage_distance := npc.global_position.distance_squared_to(storage.get_center_floor_position())
			if storage_distance < best_distance:
				best_distance = storage_distance
				best_type = fuel_type
			break

	return best_type

func _consume_carried_fuel() -> int:
	if npc.Item.current_item == null:
		return Enum.Items.WOOD
	var fuel_item_type := npc.Item.current_item.itemType
	npc.Item.current_item.destroy()
	npc.Item.current_item = null
	return fuel_item_type


static func _cleanup_occupied_fireplaces() -> void:
	occupied_fireplaces = occupied_fireplaces.filter(func(candidate: RoomFireplace): return is_instance_valid(candidate))
