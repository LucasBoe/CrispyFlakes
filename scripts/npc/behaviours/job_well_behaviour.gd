extends Behaviour
class_name JobWellBehaviour

var well
static var occupied_wells = []

func start_loop():
	well = try_get_room_if_not_occupied(data, RoomWell, occupied_wells)

func loop():
	await move(well)

	while true:
		while not well.has_water():
			await end_of_frame()
		well.register(npc)
		while well.current_user != npc:
			await end_of_frame()
		await progress(well.get_draw_duration())
		well.consume_water()
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
