extends Behaviour
class_name JobBreweryBehaviour

var brewery

static var occupied_breweries = []

func start_loop():
	brewery = try_get_room_if_not_occupied(data, RoomBrewery, occupied_breweries)

func loop():
	await move(brewery.get_random_floor_position())

	while true:

		await fetch_item(Enum.Items.WATER_BUCKET)

		if npc.Item.is_item(Enum.Items.WATER_BUCKET):
			await move(brewery.get_random_floor_position())
			var i = npc.Item.drop_current()
			i.destroy()

			await progress(20, brewery.progressBar)
			var item_spawn_pos = brewery.get_random_floor_position()
			var item = Global.ItemSpawner.create(Enum.Items.BEER_BARREL, item_spawn_pos)
			npc.Item.pick_up(item)
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
