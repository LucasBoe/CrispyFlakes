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
		
		var drink = bar.drink_type
	
		await move(bar.get_random_floor_position())
		
		if drinks_available < .1:
			
			await fetch_item(drink)
		
			if npc.Item.is_item(drink):		
				await move(bar.get_random_floor_position())
				var item = npc.Item.DropCurrent()
				item.Destroy()
				drinks_available = 1.0
				
		else:		
			await move(bar.get_random_floor_position())
			
			if bar.drinkRequests.size() > 0:
				await progress(2, bar.progressBar)
				bar.fullfill_next_request()
				drinks_available -= .2
					
				ResourceHandler.add_animated(Enum.Resources.MONEY, bar.current_upgrade.price, bar.get_center_position())
			
func stop_loop():
	ocupied_bars.erase(bar)
