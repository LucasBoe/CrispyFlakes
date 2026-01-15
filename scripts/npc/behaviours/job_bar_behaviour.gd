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
	
	while is_running:
		
		await move(bar.get_random_floor_position())
		
		if drinks_available < .1:
			var butteries = Global.Building.get_all_rooms_of_type(RoomButtery)
			var valid_butteries = []
			for b in butteries:
				if (b as RoomButtery).has(Enum.Items.WISKEY_BARREL):
					var distance_to_npc = npc.global_position.direction_to(b.get_center_position())
					valid_butteries.append([b,distance_to_npc])
			
			var wiskey_item = null
					
			if valid_butteries.size() > 0:
				valid_butteries.sort_custom(Callable(self, "custom_array_sort"))
				var buttery : RoomButtery = valid_butteries[0][0]
				await move(buttery)
				wiskey_item = buttery.Take(Enum.Items.WISKEY_BARREL)
			if wiskey_item != null:
				npc.Item.PickUp(wiskey_item)
				await move(bar.get_random_floor_position())
				var item = npc.Item.DropCurrent()
				item.Destroy()
				drinks_available = 1.0
			else:
				var wiskey_icon = Item.get_info(Enum.Items.WISKEY_BARREL).Tex
				UiNotifications.create_notification_dynamic("?", npc, Vector2(0,-32), wiskey_icon)
				
		else:		
			await move(bar.get_random_floor_position())
			
			if bar.drinkRequests.keys().size() > 0:
				await progress(2, bar.progressBar)
				var item = Global.ItemSpawner.Create(Enum.Items.WISKEY_DRINK, bar.get_random_floor_position())
				bar.drinkRequests[bar.drinkRequests.keys()[0]] = item;
				drinks_available -= .3
				ResourceHandler.add_animated(Enum.Resources.MONEY, 4, bar.get_center_position())
			
func stop_loop():
	ocupied_bars.erase(bar)

func custom_array_sort(a, b):
		return a[1] < b[1]
