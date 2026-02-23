extends RoomStorageBase
class_name RoomAgingCellar

var raw_items = {} #item - placement time
const RIPE_DURATION = Global.DAY_DURATION / 2

func TryReceive(item : Item) -> bool:
	var received = super.TryReceive(item)
	if received:
		raw_items[item] = Global.time_now
	return received

func _process(delta):
	
	var ripe = []
	for key in raw_items.keys():
		if raw_items[key] + RIPE_DURATION < Global.time_now:
			ripe.append(key)
			
	for item in ripe:
		item.itemType = Enum.Items.WISKEY_BOX
		item.refresh_texture()
		raw_items.erase(item)
