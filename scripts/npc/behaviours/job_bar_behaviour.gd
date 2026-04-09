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

		await move(bar.get_random_floor_position())

		if drinks_available < .1:

			await fetch_item(drink)

			if npc.Item.is_item(drink):
				await move(bar.get_random_floor_position())
				var item = npc.Item.drop_current()
				item.destroy()
				drinks_available = 1.0
			else:
				RoomStatusHandler.notify(bar, "no item", Color.ORANGE, bar.current_module.icon if bar.current_module else null)

		else:

			await move(bar.get_center_floor_position())

			if bar.drink_requests.size() > 0:
				await progress(.5, bar.progressBar)

				bar.fullfill_next_request()
				drinks_available -= .25

				ResourceHandler.add_animated(Enum.Resources.MONEY, bar.current_module.item_cost if bar.current_module else 0, bar.get_center_position(), Vector2i(bar.x, bar.y))
			else:
				await move(bar.get_random_floor_position())

func stop_loop() -> BehaviourSaveData:
	ocupied_bars.erase(bar)
	if is_instance_valid(bar):
		bar.worker = null

	var _data = BehaviourSaveData.new(get_script())
	_data.room = bar
	return _data
