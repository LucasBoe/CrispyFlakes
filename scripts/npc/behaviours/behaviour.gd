extends RefCounted
class_name Behaviour

var npc : NPC
var data : BehaviourSaveData
var stopped = false

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
	return BehaviourSaveData.new(get_script())

func try_get_room_if_not_occupied(saved_data, type, ocupied):
	var room = null

	if saved_data != null and not ocupied.has(saved_data.room):
		room = saved_data.room
	else:
		var reachable = npc.Navigation.get_reachable_rooms()
		room = Global.Building.query.closest_room_of_type(type, npc.global_position, ocupied, Vector2.ZERO, reachable)

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
	return Global.Building.query.all_rooms_of_type(type, reachable).pick_random()

func get_closest_room_of_type(type):
	var reachable = npc.Navigation.get_reachable_rooms()
	return Global.Building.query.closest_room_of_type(type, npc.global_position, null, Vector2.ZERO, reachable)

func get_all_rooms_of_type_ordered_by_distance(type):
	var reachable = npc.Navigation.get_reachable_rooms()
	return Global.Building.query.rooms_of_type_ordered_by_distance(type, npc.global_position, null, reachable)

func move(target, custom_speed = -1):
	var goal_pos: Vector2 = (target as Node2D).global_position if target is Node2D else target
	var goal_room := Global.Building.query.closest_room_of_type(RoomBase, goal_pos) as RoomBase

	if goal_room != null and not npc.Navigation.is_room_reachable(goal_room):
		var fallback_room := _get_closest_reachable_room_to(goal_pos)
		while fallback_room != null and not npc.Navigation.is_room_reachable(goal_room):
			npc.Navigation.set_target(fallback_room.get_random_floor_position(), -1)
			while npc.Navigation.is_moving:
				await end_of_frame()
			UiNotifications.create_notification_dynamic("?", npc, Vector2(0, -32), Global.Building.room_data_stairs.room_icon)
			await pause(3)

	npc.Navigation.set_target(target, custom_speed)
	if target is Node2D:
		while npc.Navigation.is_moving:
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

	# fetch from buttery
	for b: RoomButtery in get_all_rooms_of_type_ordered_by_distance(RoomButtery):
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
		well.register(npc)
		while well.current_user != npc:
			await end_of_frame()
		await progress(1, well.progressBar)
		source_item = Global.ItemSpawner.create(Enum.Items.WATER_BUCKET, well.get_center_position())
		well.unregister(npc)

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

	var buttery = get_closest_room_of_type(RoomButtery)
	if buttery != null:
		await move(buttery)
		if not npc.Item.try_put_to(buttery):
			await move(buttery.get_random_floor_position())
			npc.Item.drop_current()
	else:
		var current_room = Global.Building.query.room_at_position(npc.global_position) as RoomBase
		await move(current_room.get_random_floor_position())
		npc.Item.drop_current()

func progress(duration, bar: TextureProgressBar):
	var t = float(duration)
	if is_instance_valid(bar):
		bar.visible = true
	while t > 0:
		t -= npc.get_process_delta_time() #error
		if not is_instance_valid(bar):
			return
		bar.value = (1.0 - (t / duration)) * 100
		await end_of_frame()
	if is_instance_valid(bar):
		bar.visible = false

func end_of_frame():
	return Global.get_tree().process_frame
