extends Behaviour
class_name JobBarBehaviour

var bar : RoomBar
var drinks_available = 0.0

static var ocupied_bars = []

func start_loop(data : BehaviourSaveData):
	bar = try_get_room_if_not_occupied(data, RoomBar, ocupied_bars)

func loop():	
	while true:
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
			
			await move(bar.get_center_floor_position())
			if bar.drinkRequests.size() > 0:
				await progress(.5, bar.progressBar)
				bar.fullfill_next_request()
				drinks_available -= .25
					
				ResourceHandler.add_animated(Enum.Resources.MONEY, bar.current_upgrade.item_cost, bar.get_center_position())
			else:
				await move(bar.get_random_floor_position())
			
func stop_loop() -> BehaviourSaveData:
	ocupied_bars.erase(bar)
	if is_instance_valid(bar):
		bar.worker = null
	
	var data = BehaviourSaveData.new(get_script())
	data.room = bar
	return data
