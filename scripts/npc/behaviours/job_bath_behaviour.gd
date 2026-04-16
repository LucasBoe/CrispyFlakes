extends Behaviour
class_name JobBathBehaviour

var bath : RoomBath

static var occupied_rooms = []

func start_loop():
	bath = try_get_room_if_not_occupied(data, RoomBath, occupied_rooms)

func loop():
	await move(bath.get_random_floor_position())

	while true:
		var can_run_bath := false

		if bath.has_faucet:
			var tower := get_closest_room_of_type(RoomWaterTower) as RoomWaterTower
			if tower != null and tower.has_water():
				_narrative = ["Turning the faucet...", "Drawing hot water...", "Filling the tub from the tower..."].pick_random()
				await move(bath.get_center_floor_position())
				tower.consume_water()
				can_run_bath = true
			else:
				_narrative = ["Waiting for the water tower...", "No water in the pipes...", "The bath's faucet is dry..."].pick_random()
				RoomStatusHandler.notify(bath, "no water", Color.ORANGE, bath.faucet_module.icon if bath.faucet_module else null)
				await pause(2)
		else:
			_narrative = ["Fetching water...", "Filling the bucket...", "Getting water for the bath..."].pick_random()
			await fetch_item(Enum.Items.WATER_BUCKET)
			can_run_bath = npc.Item.is_item(Enum.Items.WATER_BUCKET)

		if can_run_bath:
			await move(bath.get_random_floor_position())

			if not bath.has_customer:
				_narrative = ["Waiting for a customer...", "Ready for the next guest...", "Standing by..."].pick_random()
				await bath.customer_arrive

			if npc.Item.is_item(Enum.Items.WATER_BUCKET):
				var i = npc.Item.drop_current()
				i.destroy()

			_narrative = ["Running a bath...", "Giving them a scrub...", "Drawing the bath..."].pick_random()
			await progress(6)

			ResourceHandler.add_animated(Enum.Resources.MONEY, bath.get_service_price(), bath.get_center_position(), Vector2i(bath.x, bath.y))
			bath.clean_customer()

func stop_loop():
	bath.worker = null
	occupied_rooms.erase(bath)

	var save = super.stop_loop()
	save.room = bath
	return save
