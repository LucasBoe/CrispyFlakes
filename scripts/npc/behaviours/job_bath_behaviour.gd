extends Behaviour
class_name JobBathBehaviour

var bath : RoomBath

static var occupied_rooms = []

func start_loop():
	bath = try_get_room_if_not_occupied(data, RoomBath, occupied_rooms)

func loop():
	await move(bath.get_random_floor_position())

	while true:
		await fetch_item(Enum.Items.WATER_BUCKET)

		if npc.Item.is_item(Enum.Items.WATER_BUCKET):
			await move(bath.get_random_floor_position())

			if not bath.has_customer:
				await bath.customer_arrive

			var i = npc.Item.drop_current()
			i.destroy()

			await progress(6, bath.progressBar)

			ResourceHandler.add_animated(Enum.Resources.MONEY, 4, bath.get_center_position())
			bath.clean_customer()

func stop_loop():
	bath.worker = null
	occupied_rooms.erase(bath)

	var save = super.stop_loop()
	save.room = bath
	return save
