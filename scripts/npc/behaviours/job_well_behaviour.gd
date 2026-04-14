extends Behaviour
class_name JobWellBehaviour

var well
static var occupied_wells = []

func start_loop():
	well = try_get_room_if_not_occupied(data, RoomWell, occupied_wells)

func loop():
	await move(well)

	while true:

		var loose = LooseItemHandler.get_closest_to(npc.global_position, Enum.Items.WATER_BUCKET)
		if loose != null:
			_narrative = ["Picking up a stray bucket...", "Grabbing that loose water...", "Collecting spilled water..."].pick_random()
			await move(loose.global_position)
			if is_instance_valid(loose):
				npc.Item.pick_up(loose)
				_narrative = ["Storing the bucket...", "Delivering water...", "Taking it where it's needed..."].pick_random()
				await store_item(npc.Item.current_item)
			await move(well)
			continue

		_narrative = "Waiting for water..."
		while not well.has_water():
			await end_of_frame()
		well.register(npc)
		while well.current_user != npc:
			await end_of_frame()
		_narrative = ["Drawing water...", "Cranking the bucket up...", "Pulling from the well..."].pick_random()
		await progress(well.get_draw_duration())
		well.consume_water()
		well.unregister(npc)
		var item_spawn_pos = well.get_random_floor_position()
		var item = Global.ItemSpawner.create(Enum.Items.WATER_BUCKET, item_spawn_pos)
		npc.Item.pick_up(item)
		_narrative = ["Delivering water...", "Hauling the bucket...", "Taking it where it's needed..."].pick_random()
		await store_item(item)
		await move(well)

func stop_loop():
	well.worker = null
	occupied_wells.erase(well)

	var save = super.stop_loop()
	save.room = well
	return save
