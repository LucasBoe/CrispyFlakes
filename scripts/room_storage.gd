extends RoomStorageBase
class_name RoomStorage

var allowed_items : Array = []

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	for item_type in Enum.Items.values():
		allowed_items.append(item_type)

func accepts_item_type(item_type: int) -> bool:
	return item_type in allowed_items

func can_receive(item: Item) -> bool:
	if item == null:
		return false

	var stored_item_type := item.itemType
	if item.is_trade_crate():
		stored_item_type = item.get_trade_crate_item_type()

	if stored_item_type < 0 or not accepts_item_type(stored_item_type):
		return false
	return super.can_receive(item)

func try_receive(item: Item) -> bool:
	if not can_receive(item):
		return false
	return super.try_receive(item)
