extends RoomBase
class_name RoomStairs

const GRID_SIZE = 48

@onready var stairs_background_sprite = $"Stairs-Background"
@onready var stairs_foreground_sprite = $"Stairs-Foreground"

func init_room(_x : int, _y : int):
	super.init_room(_x, _y)
	refresh_visuals()

	var room_below = Global.Building.get_room_from_index(Vector2i(x, y - 1))
	if room_below != null:
		room_below.refresh_visuals()

	var room_above = Global.Building.get_room_from_index(Vector2i(x, y + 1))
	if room_above != null:
		room_above.refresh_visuals()

func refresh_visuals():
	if x == null or y == null:
		return
	var has_above = Global.Building.get_room_from_index(Vector2i(x, y + 1)) is RoomStairs
	var has_below = Global.Building.get_room_from_index(Vector2i(x, y - 1)) is RoomStairs

	var stair_sprite_index: int
	if not has_above and has_below:
		stair_sprite_index = 0
	elif not has_below:
		stair_sprite_index = 3
	else:
		stair_sprite_index = 2 if is_basement else 1

	stairs_background_sprite.region_rect = Rect2(0, GRID_SIZE * stair_sprite_index, GRID_SIZE, GRID_SIZE)
	stairs_foreground_sprite.region_rect = Rect2(GRID_SIZE, GRID_SIZE * stair_sprite_index, GRID_SIZE, GRID_SIZE)

static func custom_placement_check(location) -> bool:

	if not Global.Building.has_any_rooms_on_x(location.x):
		return true

	if Global.Building.get_room_from_index(location + Vector2i.UP) is RoomStairs:
		return true

	if Global.Building.get_room_from_index(location + Vector2i.DOWN) is RoomStairs:
		return true

	return false
