extends Behaviour
class_name JobDestilleryBehaviour

var destillery

static var occupied_destilleries = []

func loop():
	
	destillery = Global.Building.get_closest_room_of_type(RoomDestillery, npc.global_position, occupied_destilleries)
	
	if destillery == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
		
	occupied_destilleries.append(destillery)
	destillery.worker = npc
	await move(destillery.get_random_floor_position())
	
	while is_running:
		
		await fetch_item(Enum.Items.WATER_BUCKET)
			
		if npc.Item.is_item(Enum.Items.WATER_BUCKET):
			await move(destillery.get_random_floor_position())
			var i = npc.Item.DropCurrent()
			if is_instance_valid(i):
				i.Destroy()
			
			await progress(5, destillery.progressBar)
			var itemSpawnPos = destillery.get_random_floor_position()
			var item = Global.ItemSpawner.Create(Enum.Items.WISKEY_BOX_RAW, itemSpawnPos)
			npc.Item.PickUp(item)
			await store_item(item)

func stop_loop():
	destillery.worker = null
	occupied_destilleries.erase(destillery)
