extends Behaviour
class_name ExtinguishFireBehaviour

const EXTINGUISH_DURATION := 0.1
const LIQUID_AMOUNT := 1.0
const EMERGENCY_MOVE_SPEED := 88.0

enum SourceType {
	NONE,
	PIPE,
	LOOSE_ITEM,
	STORAGE,
	WELL,
	BEER_BAR,
}

var fire = null
var _registered_well: RoomWell = null

func start_loop() -> void:
	fire = data.extra.get("fire", null) if data != null else null

func loop() -> void:
	while FireHandler.is_active_fire(fire):
		var source := _find_closest_liquid_source()
		if source["type"] == SourceType.NONE:
			_narrative = ["Looking for anything wet...", "No liquid nearby...", "Searching for water or beer..."].pick_random()
			await pause(2.0)
			continue

		var collected := await _collect_source(source)
		if stopped:
			break
		if not collected:
			continue
		if not FireHandler.is_active_fire(fire):
			_drop_carried_liquid()
			break

		_narrative = ["Dousing the fire...", "Throwing liquid on the flames...", "Putting it out..."].pick_random()
		await move(fire.room.get_random_floor_position(), EMERGENCY_MOVE_SPEED)
		if stopped or not FireHandler.is_active_fire(fire):
			_drop_carried_liquid()
			break

		SoundPlayer.play_water(npc.global_position)
		await progress(EXTINGUISH_DURATION)
		if stopped:
			break
		if not FireHandler.is_active_fire(fire):
			_drop_carried_liquid()
			break
		_consume_carried_liquid()
		FireHandler.apply_liquid(fire, LIQUID_AMOUNT)

	if stopped:
		return
	_restore_worker_job()

func stop_loop() -> BehaviourSaveData:
	_unregister_well()
	var save := super.stop_loop()
	save.extra["fire"] = fire
	return save

func _find_closest_liquid_source() -> Dictionary:
	var sources: Array[Dictionary] = []
	_add_pipe_source(sources)
	_add_item_sources(sources, Enum.Items.WATER_BUCKET)
	_add_item_sources(sources, Enum.Items.BEER_BARREL)
	_add_well_sources(sources)
	_add_beer_bar_sources(sources)

	if sources.is_empty():
		return {"type": SourceType.NONE}

	sources.sort_custom(func(a, b): return _source_distance_squared(a) < _source_distance_squared(b))
	return sources[0]

func _add_pipe_source(sources: Array[Dictionary]) -> void:
	if fire == null or not is_instance_valid(fire.room):
		return
	var tower := Building.infrastructure.get_connected_provider(fire.room, &"water") as RoomWaterTower
	if tower == null or not tower.has_water():
		return
	sources.append({
		"type": SourceType.PIPE,
		"position": fire.room.get_center_floor_position(),
		"tower": tower,
	})

func _add_item_sources(sources: Array[Dictionary], item_type: int) -> void:
	var loose := LooseItemHandler.get_closest_to(npc.global_position, item_type) as Item
	if loose != null:
		sources.append({
			"type": SourceType.LOOSE_ITEM,
			"position": loose.global_position,
			"item": loose,
			"item_type": item_type,
		})

	for storage: RoomStorage in get_all_rooms_of_type_ordered_by_distance(RoomStorage):
		if not storage.has(item_type):
			continue
		sources.append({
			"type": SourceType.STORAGE,
			"position": storage.get_center_floor_position(),
			"storage": storage,
			"item_type": item_type,
		})
		break

func _add_well_sources(sources: Array[Dictionary]) -> void:
	for well: RoomWell in get_all_rooms_of_type_ordered_by_distance(RoomWell):
		if not well.has_water():
			continue
		sources.append({
			"type": SourceType.WELL,
			"position": well.get_center_floor_position(),
			"well": well,
			"item_type": Enum.Items.WATER_BUCKET,
		})
		break

func _add_beer_bar_sources(sources: Array[Dictionary]) -> void:
	for bar: RoomBar in get_all_rooms_of_type_ordered_by_distance(RoomBar):
		if bar.drink_type != Enum.Items.BEER_BARREL:
			continue
		sources.append({
			"type": SourceType.BEER_BAR,
			"position": bar.get_center_floor_position(),
			"bar": bar,
			"item_type": Enum.Items.BEER_BARREL,
		})
		break

func _source_distance_squared(source: Dictionary) -> float:
	return npc.global_position.distance_squared_to(source.get("position", npc.global_position))

func _collect_source(source: Dictionary) -> bool:
	match int(source["type"]):
		SourceType.PIPE:
			var tower := source.get("tower", null) as RoomWaterTower
			if tower != null and tower.has_water():
				_narrative = ["Drawing from the pipes...", "Tapping the tower water...", "Getting water from the line..."].pick_random()
				await move(source["position"], EMERGENCY_MOVE_SPEED)
				tower.consume_water()
				return true
		SourceType.LOOSE_ITEM:
			var item := source.get("item", null) as Item
			if is_instance_valid(item):
				_narrative = _pickup_narrative(item.itemType)
				await move(item.global_position, EMERGENCY_MOVE_SPEED)
				if is_instance_valid(item):
					npc.Item.pick_up(item)
					return true
		SourceType.STORAGE:
			var storage := source.get("storage", null) as RoomStorage
			var item_type := int(source.get("item_type", Enum.Items.WATER_BUCKET))
			if is_instance_valid(storage) and storage.has(item_type):
				_narrative = _pickup_narrative(item_type)
				await move(storage, EMERGENCY_MOVE_SPEED)
				var item := storage.take(item_type)
				if item != null:
					npc.Item.pick_up(item)
					return true
		SourceType.WELL:
			var well := source.get("well", null) as RoomWell
			if is_instance_valid(well):
				_narrative = ["Drawing water...", "Filling a bucket...", "Pulling water up..."].pick_random()
				await move(well, EMERGENCY_MOVE_SPEED)
				while is_instance_valid(well) and not well.has_water():
					await end_of_frame()
				if not is_instance_valid(well):
					return false
				well.register(npc)
				_registered_well = well
				while is_instance_valid(well) and well.current_user != npc:
					await end_of_frame()
				SoundPlayer.play_use_well(well.global_position)
				await progress(well.get_draw_duration())
				if stopped:
					_unregister_well()
					return false
				if not is_instance_valid(well):
					_registered_well = null
					return false
				well.consume_water()
				_unregister_well()
				var item := Global.ItemSpawner.create(Enum.Items.WATER_BUCKET, well.get_center_position())
				npc.Item.pick_up(item)
				return true
		SourceType.BEER_BAR:
			var bar := source.get("bar", null) as RoomBar
			if is_instance_valid(bar):
				_narrative = ["Grabbing beer...", "Borrowing a barrel...", "Fetching beer for the flames..."].pick_random()
				await move(bar.get_random_floor_position(), EMERGENCY_MOVE_SPEED)
				await progress(0.5)
				if stopped:
					return false
				var item := Global.ItemSpawner.create(Enum.Items.BEER_BARREL, bar.get_center_floor_position())
				npc.Item.pick_up(item)
				return true
	return false

func _pickup_narrative(item_type: int) -> String:
	if item_type == Enum.Items.BEER_BARREL:
		return ["Grabbing beer...", "Hauling a beer barrel...", "Beer beats flames today..."].pick_random()
	return ["Fetching water...", "Hauling a bucket...", "Getting water..."].pick_random()

func _consume_carried_liquid() -> void:
	if npc.Item.current_item == null:
		return
	if npc.Item.is_item(Enum.Items.WATER_BUCKET) or npc.Item.is_item(Enum.Items.BEER_BARREL):
		npc.Item.current_item.destroy()
		npc.Item.current_item = null

func _drop_carried_liquid() -> void:
	if npc.Item.current_item == null:
		return
	if npc.Item.is_item(Enum.Items.WATER_BUCKET) or npc.Item.is_item(Enum.Items.BEER_BARREL):
		npc.Item.drop_current()

func _unregister_well() -> void:
	if is_instance_valid(_registered_well):
		_registered_well.unregister(npc)
	_registered_well = null

func _restore_worker_job() -> void:
	var previous_data := npc.Behaviour.previous_data
	if previous_data != null and previous_data.type != get_script():
		npc.Behaviour.restore_previous_behaviour()
	else:
		(npc as NPCWorker).resume_job_behaviour()
