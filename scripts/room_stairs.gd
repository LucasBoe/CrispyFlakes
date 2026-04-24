extends RoomBase
class_name RoomStairs

const GRID_SIZE = 48

@onready var stairs_sprite = $"Stairs"

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	refresh_visuals()

func refresh_visuals():
	if x == null or y == null:
		return
	
	var room_above =  Building.get_room_from_index(Vector2i(x, y + 1))
	var show_railing_above = y >= 0 and room_above is RoomEmpty
	var i = (1 if is_basement else 0) + (2 if show_railing_above else 0)
	stairs_sprite.region_rect = Rect2(i * GRID_SIZE, 0, GRID_SIZE, GRID_SIZE * 2)
