extends Behaviour
class_name JobWellBehaviour

var well

static var occupied_wells = []

func loop():
	well = Global.Building.get_closest_room_of_type(RoomWell, npc.global_position, occupied_wells)
	
	if well == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
	
	occupied_wells.append(well)
	
	await move(well)
	
	while is_running:
		well.register(npc)
		while well.current_user != npc:
			await endOfFrame()
		await progress(1, well.progressBar)
		well.unregister(npc)
		var itemSpawnPos = well.get_random_floor_position()
		var item = Global.ItemSpawner.Create(Enum.Items.WATER_BUCKET, itemSpawnPos)
		npc.Item.PickUp(item)
		await store_item(item)
		await move(well)

func stop_loop():
	occupied_wells.erase(well)
