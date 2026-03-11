extends Behaviour
class_name JobWellBehaviour

var well
static var occupied_wells = []

func start_loop():
	well = try_get_room_if_not_occupied(data, RoomWell, occupied_wells)

func loop():
	await move(well)

	while true:
		well.register(npc)
		while well.current_user != npc:
			await end_of_frame()
		await progress(1, well.progressBar)
		well.unregister(npc)
		var item_spawn_pos = well.get_random_floor_position()
		var item = Global.ItemSpawner.create(Enum.Items.WATER_BUCKET, item_spawn_pos)
		npc.Item.pick_up(item)
		await store_item(item)
		await move(well)

func stop_loop():
	well.worker = null
	occupied_wells.erase(well)

	var save = super.stop_loop()
	save.room = well
	return save
