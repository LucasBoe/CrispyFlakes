extends Behaviour
class_name JobBarBehaviour

var bar : RoomBar
var drinks_available = 0.0

static var ocupied_bars = []

func start_loop():
	bar = try_get_room_if_not_occupied(data, RoomBar, ocupied_bars)

func loop():
	while true:
		var drink = bar.drink_type

		if drinks_available < .1:

			if bar.has_faucet and drink == Enum.Items.WATER_BUCKET:
				var tower := get_closest_room_of_type(RoomWaterTower) as RoomWaterTower
				if tower != null and tower.has_water():
					_narrative = ["Tapping the faucet...", "Drawing from the pipe...", "Filling up from the tower..."].pick_random()
					await move(bar.get_center_floor_position())
					tower.consume_water()
					drinks_available = 1.0
				else:
					_narrative = ["Waiting for the water tower...", "Tower's dry...", "No water in the pipe..."].pick_random()
					RoomStatusHandler.notify(bar, "no water", Color.ORANGE, bar.current_module.icon if bar.current_module else null)
					await pause(2)
			else:
				_narrative = "Fetching drinks..."
				npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
				await fetch_item(drink)

				if npc.Item.is_item(drink):
					_narrative = "Restocking the bar..."
					await move(bar.get_random_floor_position())
					var item = npc.Item.drop_current()
					if is_instance_valid(item):
						item.destroy()
						drinks_available = 1.0
				else:
					RoomStatusHandler.notify(bar, "no item", Color.ORANGE, bar.current_module.icon if bar.current_module else null)

		else:

			npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_ROOM_CONTENT)
			await move(bar.get_center_floor_position())

			if bar.drink_requests.size() > 0:
				_narrative = "Serving drinks..."
				await progress(.5)

				bar.fullfill_next_request()
				drinks_available -= .25

				ResourceHandler.add_animated(Enum.Resources.MONEY, bar.current_module.item_cost if bar.current_module else 0, bar.get_center_position(), Vector2i(bar.x, bar.y))
			else:
				_narrative = "Waiting for orders..."
				await pause(1)

func stop_loop() -> BehaviourSaveData:
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	ocupied_bars.erase(bar)
	if is_instance_valid(bar):
		bar.worker = null

	var _data = BehaviourSaveData.new(get_script())
	_data.room = bar
	return _data
