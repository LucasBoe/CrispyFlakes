extends Behaviour
class_name JobBreweryBehaviour

var brewery

static var occupied_breweries = []

func start_loop():
	brewery = try_get_room_if_not_occupied(data, RoomBrewery, occupied_breweries)

func loop():
	await move(brewery.get_random_floor_position())

	while true:

		var tower := get_closest_room_of_type(RoomWaterTower) as RoomWaterTower
		if tower != null and tower.has_water():
			_narrative = ["Drawing from the tower...", "Tapping the water supply...", "Filling up from the pipe..."].pick_random()
			await move(brewery.get_random_floor_position())
			tower.consume_water()
		else:
			_narrative = ["Fetching water...", "Going for water...", "Filling up the bucket..."].pick_random()
			await fetch_item(Enum.Items.WATER_BUCKET)
			if not npc.Item.is_item(Enum.Items.WATER_BUCKET):
				continue
			await move(brewery.get_random_floor_position())
			var i = npc.Item.drop_current()
			if not is_instance_valid(i):
				continue
			i.destroy()

			_narrative = ["Brewing...", "Watching the ferment...", "Tending the kettle..."].pick_random()
			var duration = brewery.current_module.brew_duration if brewery.current_module else 20.0
			await progress(duration)
			var item_spawn_pos = brewery.get_random_floor_position()
			var item = Global.ItemSpawner.create(Enum.Items.BEER_BARREL, item_spawn_pos)
			npc.Item.pick_up(item)
			_narrative = ["Lifting the beer...", "Hauling the barrels...", "Storing the kegs..."].pick_random()
			await store_item(item)

func custom_array_sort(a, b):
		return a[1] < b[1]

func stop_loop():
	if brewery:
		brewery.worker = null
	occupied_breweries.erase(brewery)

	var save = super.stop_loop()
	save.room = brewery
	return save
