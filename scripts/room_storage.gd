extends RoomStorageBase
class_name RoomStorage

var allowed_items : Array = []

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	for item_type in Enum.Items.values():
		allowed_items.append(item_type)

func can_receive(item: Item) -> bool:
	if item == null or item.itemType not in allowed_items:
		return false
	return super.can_receive(item)

func try_receive(item: Item) -> bool:
	if not can_receive(item):
		return false
	return super.try_receive(item)
