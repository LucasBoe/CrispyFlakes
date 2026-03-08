extends Behaviour
class_name JobWellBehaviour

var well
static var occupied_wells = []

func start_loop(data : BehaviourSaveData):
	well = try_get_room_if_not_occupied(data, RoomWell, occupied_wells)
	
func loop():
	
	if well == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
	
	well.worker = npc
	occupied_wells.append(well)
	
	await move(well)
	
	while true:
		well.register(npc)
		while well.current_user != npc:
			await end_of_frame()
		await progress(1, well.progressBar)
		well.unregister(npc)
		var itemSpawnPos = well.get_random_floor_position()
		var item = Global.ItemSpawner.Create(Enum.Items.WATER_BUCKET, itemSpawnPos)
		npc.Item.PickUp(item)
		await store_item(item)
		await move(well)

func stop_loop():
	well.worker = null
	occupied_wells.erase(well)
	
	var save = super.stop_loop()
	save.room = well
	return save
