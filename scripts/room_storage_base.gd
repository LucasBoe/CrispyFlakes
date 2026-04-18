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
		if items[i] && (items[i] as Item).itemType == itemType:
			var item = items[i]
			items[i] = null
			item.play_spawn_sound()
			return item

	return null

func has(itemType : Enum.Items):
	for i in (max_x * max_y):
		if items[i] && (items[i] as Item).itemType == itemType:
			return true

	return false

func get_next_free_slot() -> int:
	for i in (max_x * max_y):
		if not items[i]:
			return i

	return -1

func index_to_xy(index: int) -> Vector2:
	var col = float(index % max_x)
	var row = float(index / max_x)

	var x = offset_x + (col / max_x) * 34
	var y = -1 - ((max_y - 1 - row) / max_y) * 35.0

	return Vector2(x, y)
