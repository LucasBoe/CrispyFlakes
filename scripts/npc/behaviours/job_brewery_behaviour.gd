extends Behaviour
class_name JobBreweryBehaviour

var brewery

func loop():
	brewery = Global.Building.get_closest_room_of_type(RoomBrewery, npc.global_position)
	
	while isRunning:
		await progress(6, brewery.progressBar)
		#await pause(1)
		var itemSpawnPos = brewery.get_random_floor_position()
		var item = Global.ItemSpawner.Create(Enum.Items.WISKEY_BARREL, itemSpawnPos)
		npc.Item.PickUp(item)
		var closestButtery = Global.Building.get_closest_room_of_type(RoomButtery, npc.global_position)
		await move(closestButtery)
		if not npc.Item.TryPutTo(closestButtery):
			await move(closestButtery.get_random_floor_position())
			npc.Item.DropCurrent()
		await move(brewery)
