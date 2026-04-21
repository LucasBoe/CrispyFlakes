extends Behaviour
class_name JobDestilleryBehaviour

var destillery

static var occupied_destilleries = []

func start_loop():
	destillery = try_get_room_if_not_occupied(data, RoomDestillery, occupied_destilleries)

func loop():
	await move(destillery.get_random_floor_position())

	while true:

		var got_water := false
		var tower := get_closest_room_of_type(RoomWaterTower) as RoomWaterTower
		if destillery.has_faucet:
			got_water = await try_fetch_from_tower(destillery.get_random_floor_position())
		if not got_water:
		_narrative = ["Fetching water...", "Getting water for the still...", "Filling up..."].pick_random()
		await fetch_item(Enum.Items.WATER_BUCKET)

		if npc.Item.is_item(Enum.Items.WATER_BUCKET):
				got_water = true
			await move(destillery.get_random_floor_position())
			var i = npc.Item.drop_current()
			if is_instance_valid(i):
				i.destroy()

		if got_water:
			_narrative = ["Working the still...", "Distilling the whiskey...", "Checking the proof..."].pick_random()
			await progress(5)
			var item_spawn_pos = destillery.get_random_floor_position()
			var item = Global.ItemSpawner.create(Enum.Items.WISKEY_BOX_RAW, item_spawn_pos)
			npc.Item.pick_up(item)
			_narrative = ["Storing the whiskey...", "Getting it to the cellar...", "Hauling the crates..."].pick_random()
			await store_item(item)

func stop_loop():
	destillery.worker = null
	occupied_destilleries.erase(destillery)

	var save = super.stop_loop()
	save.room = destillery
	return save
