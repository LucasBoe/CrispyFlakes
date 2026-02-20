extends Node
class_name Behaviour

var npc : NPC
var is_running = true

func _init():
	start_loop()
	
func start_loop():	
	while not npc:
		await endOfFrame()	
		
	await loop()
	
	if is_instance_valid(npc):
		npc.Behaviour.clear_behaviour()

#optional override
func stop_loop():
	return
	
#mandatory override
func loop():
	print("loop base, make sure to override in inheriting scripts")
	
func move(target, custom_speed = -1):
	npc.Navigation.set_target(target, custom_speed)
	while npc.Navigation.is_moving:	
		await endOfFrame()
	
func pause(duration):
	return get_tree().create_timer(duration).timeout
	
func fetch_item(item : Enum.Items):
	var source_item = null
	
	var closest_loose_item = LooseItemHandler.get_closest_to(npc.global_position, item)
			
	#fetch source item from buttery
	var butteries = Global.Building.get_all_rooms_of_type(RoomButtery)
	var valid_butteries = []
	for b in butteries:
		if (b as RoomButtery).has(item):
			var distance_to_npc = npc.global_position.direction_to(b.get_center_position())
			valid_butteries.append([b,distance_to_npc])
	
	if valid_butteries.size() > 0:
		valid_butteries.sort_custom(Callable(self, "custom_array_sort"))
		var buttery : RoomButtery = valid_butteries[0][0]
		
		if closest_loose_item == null or npc.global_position.distance_to(buttery.global_position) < npc.global_position.distance_to(closest_loose_item.global_position):
			await move(buttery)
			source_item = buttery.Take(item)
		
	if source_item == null and closest_loose_item != null:
		await move(closest_loose_item)
		source_item = closest_loose_item
				
	#if water, fetch from well
	if source_item == null and item == Enum.Items.WATER_BUCKET:
		var well = Global.Building.get_closest_room_of_type(RoomWell, npc.global_position)
		await move(well)
		well.register(npc)
		while well.current_user != npc:
			await endOfFrame()
		
		await progress(1, well.progressBar)
		source_item = Global.ItemSpawner.Create(Enum.Items.WATER_BUCKET, well.get_center_position())
		well.unregister(npc)
				
	if source_item != null:
		npc.Item.PickUp(source_item)
	else	:
		await pause(3)
		var icon = Item.get_info(item).Tex
		UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32), icon)
		
func store_item(item):
	var closestButtery = Global.Building.get_closest_room_of_type(RoomButtery, npc.global_position)
	if closestButtery != null:
		await move(closestButtery)
		if not npc.Item.TryPutTo(closestButtery):
			await move(closestButtery.get_random_floor_position())
			npc.Item.DropCurrent()
	else:
		await move((Global.Building.get_current_room_from_global_position(npc.global_position) as RoomBase).get_random_floor_position())
		npc.Item.DropCurrent()
				
func progress(duration, bar : TextureProgressBar):
	var t = float(duration)
	bar.visible = true
	while t > 0:
		t -= get_process_delta_time()
		bar.value = (1.0 - (t / duration)) * 100
		await endOfFrame()
		
	bar.visible = false
	
func endOfFrame():
	return get_tree().process_frame

func custom_array_sort(a, b):
		return a[1] < b[1]
