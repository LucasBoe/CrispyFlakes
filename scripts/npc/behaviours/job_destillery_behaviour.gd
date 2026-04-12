extends Behaviour
class_name JobDestilleryBehaviour

var destillery

static var occupied_destilleries = []

func start_loop():
	destillery = try_get_room_if_not_occupied(data, RoomDestillery, occupied_destilleries)

func loop():
	await move(destillery.get_random_floor_position())

	while true:

		await fetch_item(Enum.Items.WATER_BUCKET)

		if npc.Item.is_item(Enum.Items.WATER_BUCKET):
			await move(destillery.get_random_floor_position())
			var i = npc.Item.drop_current()
			if is_instance_valid(i):
				i.destroy()

			await progress(5)
			var item_spawn_pos = destillery.get_random_floor_position()
			var item = Global.ItemSpawner.create(Enum.Items.WISKEY_BOX_RAW, item_spawn_pos)
			npc.Item.pick_up(item)
			await store_item(item)

func stop_loop():
	destillery.worker = null
	occupied_destilleries.erase(destillery)

	var save = super.stop_loop()
	save.room = destillery
	return save
