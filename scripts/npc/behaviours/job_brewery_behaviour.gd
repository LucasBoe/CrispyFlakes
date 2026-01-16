extends Behaviour
class_name JobBreweryBehaviour

var brewery

static var occupied_breweries = []

func loop():
	
	brewery = Global.Building.get_closest_room_of_type(RoomBrewery, npc.global_position, occupied_breweries)
	
	if brewery == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
		
	occupied_breweries.append(brewery)
	await move(brewery.get_random_floor_position())
	
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
			await move(brewery.get_random_floor_position())
			var i = npc.Item.DropCurrent()
			i.Destroy()
			
			await progress(6, brewery.progressBar)
			var itemSpawnPos = brewery.get_random_floor_position()
			var item = Global.ItemSpawner.Create(Enum.Items.BEER_BARREL, itemSpawnPos)
			npc.Item.PickUp(item)
			var closestButtery = Global.Building.get_closest_room_of_type(RoomButtery, npc.global_position)
			await move(closestButtery)
			if not npc.Item.TryPutTo(closestButtery):
				await move(closestButtery.get_random_floor_position())
				npc.Item.DropCurrent()
		else:
			await pause(3)
			var water_icon = Item.get_info(Enum.Items.WATER_BUCKET).Tex
			UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32), water_icon)	
			
func custom_array_sort(a, b):
		return a[1] < b[1]

func stop_loop():
	occupied_breweries.erase(brewery)
