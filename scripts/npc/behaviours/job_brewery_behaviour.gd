extends Behaviour
class_name JobBreweryBehaviour

var brewery

static var occupied_breweries = []

func loop():
	
	brewery = Global.Building.get_closest_room_of_type(RoomBrewery, npc.global_position, occupied_breweries)
	
	if brewery == null:
		npc.change_job(Enum.Jobs.IDLE)
		return
		
	occupied_breweries.append(brewery)
	brewery.worker = npc
	await move(brewery.get_random_floor_position())
	
	while is_running:
		
		await fetch_item(Enum.Items.WATER_BUCKET)
			
		if npc.Item.is_item(Enum.Items.WATER_BUCKET):
			await move(brewery.get_random_floor_position())
			var i = npc.Item.DropCurrent()
			i.Destroy()
			
			await progress(20, brewery.progressBar)
			var itemSpawnPos = brewery.get_random_floor_position()
			var item = Global.ItemSpawner.Create(Enum.Items.BEER_BARREL, itemSpawnPos)
			npc.Item.PickUp(item)
			await store_item(item)
			
func custom_array_sort(a, b):
		return a[1] < b[1]

func stop_loop():
	brewery.worker = null
	occupied_breweries.erase(brewery)
