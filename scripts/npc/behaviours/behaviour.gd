extends RefCounted
class_name Behaviour

var npc : NPC
var data : BehaviourSaveData
var stopped = false
var _narrative: String = "Busy..."
var _active_progress_bars: Array[TextureProgressBar] = []
var _owned_progress_bars: Array[TextureProgressBar] = []

func get_narrative() -> String:
	return _narrative

func _init(_npc, _data : BehaviourSaveData):
	npc = _npc
	data = _data

func run():

	start_loop()

	await npc.get_tree().process_frame

	if stopped:
		return

	await loop()

	if stopped:
		return

	if is_instance_valid(npc):
		npc.Behaviour.clear_behaviour()

#optional override
func start_loop():
	return

#mandatory override
func loop():
	print("loop base, make sure to override in inheriting scripts")

#optional override
func stop_loop() -> BehaviourSaveData:
	_cleanup_progress_bars()
	return BehaviourSaveData.new(get_script())

func try_get_room_if_not_occupied(saved_data, type, ocupied):
	var room = null

	if saved_data != null and not ocupied.has(saved_data.room):
		room = saved_data.room
	else:
		var reachable = npc.Navigation.get_reachable_rooms()
		room = Building.query.closest_room_of_type(type, npc.global_position, ocupied, Vector2.ZERO, reachable)

	if room == null:
		_change_to_idle()
		return null

	ocupied.append(room)
	room.worker = npc
	room.on_destroy_signal.connect(_change_to_idle)
	return room

func _change_to_idle():
	npc.change_job(Enum.Jobs.IDLE)

func get_random_room_of_type(type):
	var reachable = npc.Navigation.get_reachable_rooms()
	var rooms = Building.query.all_rooms_of_type(type, reachable)
	if rooms.is_empty():
		return null
	return rooms.pick_random()

func get_guest_allowed_random_floor_position(drunkenness: float) -> Vector2:
	var reachable = npc.Navigation.get_reachable_rooms()
	var allowed: Array[RoomBase] = []
	for room: RoomBase in reachable:
		if drunkenness < 0.3:
			if room.is_outside_room or room.is_basement:
				continue
			if room is RoomBrewery or room is RoomDestillery or room is RoomAgingCellar or room is RoomWell or room is RoomStorage or room is RoomBroomCloset:
				continue
		elif drunkenness < 0.7:
			if room.is_outside_room or room.is_basement:
				continue
		allowed.append(room)
	if allowed.is_empty():
		allowed = reachable
	return allowed.pick_random().get_random_floor_position()

func get_closest_room_of_type(type):
	var reachable = npc.Navigation.get_reachable_rooms()
	return Building.query.closest_room_of_type(type, npc.global_position, null, Vector2.ZERO, reachable)

func try_fetch_from_tower(move_target: Vector2) -> bool:
	var tower := get_closest_room_of_type(RoomWaterTower) as RoomWaterTower
	if tower == null or not tower.has_water():
		return false
	_narrative = ["Drawing from the tower...", "Tapping the water supply...", "Filling up from the pipe..."].pick_random()
	await move(move_target)
	tower.consume_water()
	return true

func get_all_rooms_of_type_ordered_by_distance(type):
	var reachable = npc.Navigation.get_reachable_rooms()
	return Building.query.rooms_of_type_ordered_by_distance(type, npc.global_position, null, reachable)

func move(target, custom_speed = -1):
	var goal_pos: Vector2 = (target as Node2D).global_position if target is Node2D else target
	var goal_room := Building.query.closest_room_of_type(RoomBase, goal_pos) as RoomBase

	if goal_room != null and not npc.Navigation.is_room_reachable(goal_room):
		var fallback_room := _get_closest_reachable_room_to(goal_pos)
		while fallback_room != null and is_instance_valid(goal_room) and not npc.Navigation.is_room_reachable(goal_room):
			npc.Navigation.set_target(fallback_room.get_random_floor_position(), -1)
			while npc.Navigation.is_moving:
				await end_of_frame()
			UiNotifications.create_notification_dynamic("?", npc, Vector2(0, -32), Building.room_data_stairs.room_icon)
			await pause(3)

	npc.Navigation.set_target(target, custom_speed)
	if target is NPC:
		while is_instance_valid(target) and npc.Navigation.is_moving:
			if not npc.Navigation.is_on_stair_path():
				npc.Navigation.refresh_target_path()
			await end_of_frame()
	else:
		while npc.Navigation.is_moving:
			await end_of_frame()


func _get_closest_reachable_room_to(goal_pos: Vector2) -> RoomBase:
	var closest: RoomBase = null
	var closest_dist := INF
	for room: RoomBase in npc.Navigation.get_reachable_rooms():
		var dist = goal_pos.distance_to(room.get_center_position())
		if dist < closest_dist:
			closest_dist = dist
			closest = room
	return closest

func pause(duration):
	return npc.get_tree().create_timer(duration).timeout #error

func fetch_item(item: Enum.Items):
	if npc.Item.current_item and npc.Item.current_item.itemType == item:
		return

	var source_item = null
	var closest_loose_item = LooseItemHandler.get_closest_to(npc.global_position, item)

	# fetch from storage
	for b: RoomStorage in get_all_rooms_of_type_ordered_by_distance(RoomStorage):
		if b.has(item):
			if closest_loose_item == null or npc.global_position.distance_to(b.global_position) < npc.global_position.distance_to(closest_loose_item.global_position):
				await move(b)
				source_item = b.take(item)
			break

	if source_item == null and closest_loose_item != null:
		await move(closest_loose_item)
		source_item = closest_loose_item

	# fetch whiskey from aging cellar
	if source_item == null and item == Enum.Items.WISKEY_BOX:
		for c: RoomAgingCellar in get_all_rooms_of_type_ordered_by_distance(RoomAgingCellar):
			if c.has(item):
				await move(c)
				source_item = c.take(item)
				break

	# fetch water from well
	if source_item == null and item == Enum.Items.WATER_BUCKET:
		var well = get_closest_room_of_type(RoomWell)
		await move(well)
		while not well.has_water():
			await end_of_frame()
		well.register(npc)
		while well.current_user != npc:
			await end_of_frame()
		
		SoundPlayer.play_use_well(well.global_position)
		await progress(well.get_draw_duration())
		well.consume_water()
		source_item = Global.ItemSpawner.create(Enum.Items.WATER_BUCKET, well.get_center_position())
		well.unregister(npc)

	if source_item == null and item == Enum.Items.BROOM:
		var broom = LooseItemHandler.get_closest_to(npc.global_position, Enum.Items.BROOM)
		if broom != null:
			await move(broom)
			source_item = broom

		if source_item == null:
			var closet = get_closest_room_of_type(RoomBroomCloset) as RoomBroomCloset
			if closet != null:
				await move(closet.get_broom_pickup_position())
				source_item = closet.issue_broom()

	if source_item != null:
		npc.Item.pick_up(source_item)
	else:
		await pause(3)
		UiNotifications.create_notification_dynamic("?", npc, Vector2(0, -32), Item.get_info(item).Tex)

func store_item(item: Item):
	if item.itemType == Enum.Items.WISKEY_BOX_RAW:
		var cellar = get_closest_room_of_type(RoomAgingCellar)
		if cellar != null:
			await move(cellar)
			if not npc.Item.try_put_to(cellar):
				await move(cellar.get_random_floor_position())
				npc.Item.drop_current()
		return

	var source_room = Building.query.room_at_position(npc.global_position) as RoomBase
	for storage: RoomStorage in get_all_rooms_of_type_ordered_by_distance(RoomStorage):
		if not storage.can_receive(item):
			continue

		await move(storage)
		if npc.Item.try_put_to(storage):
			return

	if source_room != null:
		await move(source_room.get_random_floor_position())
	npc.Item.drop_current()

const _NPC_PROGRESS_BAR = preload("res://scenes/npc_progress_bar.tscn")

func progress(duration, bar: TextureProgressBar = null):
	var owned_bar: TextureProgressBar = null
	if bar == null:
		owned_bar = _NPC_PROGRESS_BAR.instantiate() as TextureProgressBar
		npc.add_child(owned_bar)
		bar = owned_bar
		_owned_progress_bars.append(owned_bar)

	_register_progress_bar(bar)

	var t = float(duration)
	if is_instance_valid(bar):
		bar.visible = true
	while t > 0:
		if stopped:
			break
		t -= npc.get_process_delta_time()
		if not is_instance_valid(bar):
			_unregister_progress_bar(bar)
			_unregister_owned_progress_bar(owned_bar)
			return
		bar.value = (1.0 - (t / duration)) * 100
		await end_of_frame()
	if is_instance_valid(bar):
		bar.visible = false

	if is_instance_valid(owned_bar):
		owned_bar.queue_free()

	_unregister_progress_bar(bar)
	_unregister_owned_progress_bar(owned_bar)

func _register_progress_bar(bar: TextureProgressBar) -> void:
	if is_instance_valid(bar) and not _active_progress_bars.has(bar):
		_active_progress_bars.append(bar)

func _unregister_progress_bar(bar: TextureProgressBar) -> void:
	if bar != null:
		_active_progress_bars.erase(bar)

func _unregister_owned_progress_bar(bar: TextureProgressBar) -> void:
	if bar != null:
		_owned_progress_bars.erase(bar)

func _cleanup_progress_bars() -> void:
	for bar in _active_progress_bars:
		if is_instance_valid(bar):
			bar.visible = false

	for bar in _owned_progress_bars:
		if is_instance_valid(bar):
			bar.queue_free()

	_active_progress_bars.clear()
	_owned_progress_bars.clear()

func add_satisfaction(amount: float, reason: String = ""):
	if npc != null and npc.has_method("add_satisfaction"):
		npc.add_satisfaction(amount, reason)
		return

	npc.Needs.satisfaction.strength += amount
	if amount > 0.5:
		npc.notify(UiNotifications.ICON_PLUS_3)
	elif amount > 0.25:
		npc.notify(UiNotifications.ICON_PLUS_2)
	else:
		npc.notify(UiNotifications.ICON_PLUS_1)

func end_of_frame():
	return Global.get_tree().process_frame
