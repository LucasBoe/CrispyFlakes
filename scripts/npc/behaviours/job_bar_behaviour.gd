extends Behaviour
class_name JobBarBehaviour

var bar : RoomBar
var drinks_available = 0.0

static var ocupied_bars = []

func loop():
	
	bar = Global.Building.get_closest_room_of_type(RoomBar, npc.global_position, ocupied_bars)
	
	if bar == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
	
	ocupied_bars.append(bar)
	var drink = bar.drink_type
	
	while is_running:
		
		await move(bar.get_random_floor_position())
		
		if drinks_available < .1:
			
			var source_item = null
			
			#fetch source item from buttery
			var butteries = Global.Building.get_all_rooms_of_type(RoomButtery)
			var valid_butteries = []
			for b in butteries:
				if (b as RoomButtery).has(drink):
					var distance_to_npc = npc.global_position.direction_to(b.get_center_position())
					valid_butteries.append([b,distance_to_npc])
			if valid_butteries.size() > 0:
				valid_butteries.sort_custom(Callable(self, "custom_array_sort"))
				var buttery : RoomButtery = valid_butteries[0][0]
				await move(buttery)
				source_item = buttery.Take(drink)
				
			#if water, fetch from well
			if source_item == null and drink == Enum.Items.WATER_BUCKET:
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
				await move(bar.get_random_floor_position())
				var item = npc.Item.DropCurrent()
				item.Destroy()
				drinks_available = 1.0
			else:
				var wiskey_icon = Item.get_info(drink).Tex
				UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32), wiskey_icon)
				
		else:		
			await move(bar.get_random_floor_position())
			
			if bar.drinkRequests.size() > 0:
				await progress(2, bar.progressBar)
				bar.fullfill_next_request()
				drinks_available -= .3
				
				var payment = 1
				if drink == Enum.Items.BEER_BARREL:
					payment = 3
				elif drink == Enum.Items.WISKEY_BOX:
					payment = 5
					
				ResourceHandler.add_animated(Enum.Resources.MONEY, payment, bar.get_center_position())
			
func stop_loop():
	ocupied_bars.erase(bar)

func custom_array_sort(a, b):
		return a[1] < b[1]
