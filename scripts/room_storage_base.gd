extends RoomBase
class_name RoomStorageBase

@export var offset_x = 8
@export var max_x = 9
@export var max_y = 3
var items = []

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	items.resize(max_x * max_y)
	items.fill(null)

func can_receive(item: Item) -> bool:
	return item != null and get_next_free_slot() >= 0

func try_receive(item : Item) -> bool:
	if not can_receive(item):
		return false

	var free_slot_index = get_next_free_slot()

	if free_slot_index >= 0:
		item.reparent(self, false)
		item.position = index_to_xy(free_slot_index)
		item.global_rotation = 0
		item.scale = Vector2.ONE
		item.z_index = -(max_x * max_y) + free_slot_index
		items[free_slot_index] = item
		item.play_spawn_sound()
		return true
	else:
		return false

func take(itemType : Enum.Items) -> Item:
	for i in (max_x * max_y):
		var item := _get_item_at_index(i)
		if item != null and item.itemType == itemType:
			return take_item_instance(item)

	return null

func has(itemType : Enum.Items):
	for i in (max_x * max_y):
		var item := _get_item_at_index(i)
		if item != null and item.itemType == itemType:
			return true

	return false

func get_next_free_slot() -> int:
	for i in (max_x * max_y):
		if _get_item_at_index(i) == null:
			return i

	return -1

func get_slot_capacity() -> int:
	return max_x * max_y

func get_occupied_slot_count() -> int:
	var occupied := 0
	for i in get_slot_capacity():
		if _get_item_at_index(i) != null:
			occupied += 1
	return occupied

func get_floor_position_for_slot(index: int) -> Vector2:
	if index < 0:
		return get_center_floor_position()
	return global_position + Vector2(index_to_xy(index).x, 0.0)

func get_next_free_slot_floor_position() -> Vector2:
	return get_floor_position_for_slot(get_next_free_slot())

func get_stored_items() -> Array[Item]:
	var stored: Array[Item] = []
	for i in (max_x * max_y):
		var item := _get_item_at_index(i)
		if item != null:
			stored.append(item)
	return stored

func get_stored_item_amounts() -> Dictionary:
	var stored_amounts := {}
	for item in get_stored_items():
		var stored_item_type := int(item.itemType)
		var stored_amount := 1
		if item.is_trade_crate():
			stored_item_type = item.get_trade_crate_item_type()
			stored_amount = item.get_trade_crate_item_amount()
		stored_amounts[stored_item_type] = int(stored_amounts.get(stored_item_type, 0)) + stored_amount
	return stored_amounts

func remove_item(item: Item) -> bool:
	if item == null:
		return false

	for i in (max_x * max_y):
		if _get_item_at_index(i) == item:
			items[i] = null
			return true

	return false

func take_item_instance(item: Item) -> Item:
	if not remove_item(item):
		return null
	item.play_spawn_sound()
	return item

func index_to_xy(index: int) -> Vector2:
	var col = float(index % max_x)
	var row = float(index / max_x)

	var x = offset_x + (col / max_x) * 34
	var y = -1 - ((max_y - 1 - row) / max_y) * 35.0

	return Vector2(x, y)

func _get_item_at_index(index: int) -> Item:
	var item := items[index] as Item
	if item == null or not is_instance_valid(item):
		items[index] = null
		return null
	return item
