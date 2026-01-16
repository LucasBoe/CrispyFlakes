extends RoomBase
class_name RoomButtery

var items = []
var maxX = 9
var maxY = 3

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	items.resize(maxX * maxY)
	items.fill(null)

func TryReceive(item : Item) -> bool:
	var freeSlotIndex = get_next_free_slot()
	
	if freeSlotIndex >= 0:
		item.reparent(self, false)
		item.global_position = index_to_xy(freeSlotIndex)
		item.global_rotation = 0
		item.scale = Vector2.ONE
		item.z_index = -(maxX * maxY) + freeSlotIndex
		items[freeSlotIndex] = item
		return true
	else:
		return false
		
func Take(itemType : Enum.Items) -> Item:
	for i in (maxX * maxY):	
		if items[i] && (items[i] as Item).itemType == itemType:
			var item = items[i]
			items[i] = null
			return item
	
	return null

func has(itemType : Enum.Items):
	for i in (maxX * maxY):	
		if items[i] && (items[i] as Item).itemType == itemType:
			return true
	
	return false

func get_next_free_slot() -> int:
	for i in (maxX * maxY):	
		if not items[i]:
			return i
			
	return -1

func index_to_xy(index: int) -> Vector2:
	var col = float(index % maxX)
	var row = float(index / maxX)

	var x = 8 + (col / maxX) * 34
	var y = -1 - ((maxY - 1 - row) / maxY) * 35.0
	
	return Vector2(x, y)
