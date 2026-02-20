extends Behaviour
class_name JobBathBehaviour

var bath : RoomBath

static var occupied_rooms = []

func loop():
	
	bath = Global.Building.get_closest_room_of_type(RoomBath, npc.global_position, occupied_rooms)
	
	if bath == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
		
	occupied_rooms.append(bath)
	bath.worker = npc
	await move(bath.get_random_floor_position())
	
	while is_running:
		var water_item = null
		
		#fetch water from buttery
		var butteries = Global.Building.get_all_rooms_of_type(RoomButtery)
		var valid_butteries = []
		for b in butteries:
			if (b as RoomButtery).has(Enum.Items.WATER_BUCKET):
					var distance_to_npc = npc.global_position.direction_to(b.get_center_position())
					valid_butteries.append([b,distance_to_npc])
		if valid_butteries.size() > 0:
			valid_butteries.sort_custom(Callable(self, "custom_array_sort"))
			var buttery : RoomButtery = valid_butteries[0][0]
			await move(buttery)
			water_item = buttery.Take(Enum.Items.WATER_BUCKET)
		
		#fetch water from well
		if water_item == null:
			var well = Global.Building.get_closest_room_of_type(RoomWell, npc.global_position)
			await move(well)
			well.register(npc)
			while well.current_user != npc:
				await endOfFrame()
			await progress(1, well.progressBar)
			water_item = Global.ItemSpawner.Create(Enum.Items.WATER_BUCKET, well.get_center_position())
			well.unregister(npc)
			
		if water_item != null:
			npc.Item.PickUp(water_item)
			await move(bath.get_random_floor_position())
			
			if not bath.has_customer:
				await bath.customer_arrive
			
			var i = npc.Item.DropCurrent()
			i.Destroy()
			
			await progress(6, bath.progressBar)
			
			ResourceHandler.add_animated(Enum.Resources.MONEY, 4, bath.get_center_position())
			bath.clean_customer()
		else:
			await pause(3)
			var water_icon = Item.get_info(Enum.Items.WATER_BUCKET).Tex
			UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32), water_icon)	
			
func custom_array_sort(a, b):
		return a[1] < b[1]

func stop_loop():
	bath.worker = null
	occupied_rooms.erase(bath)
