extends RoomEmpty
class_name RoomStairs

const GRID_SIZE = 48

@onready var stairsBackgroundSprite = $"Stairs-Background"
@onready var stairsForegroundSprite = $"Stairs-Foreground"

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
	refresh_visuals(x,y)
	
	var room_below = Global.Building.get_room_from_index(Vector2i(x, y - 1))
	if room_below != null:
		room_below.refresh_visuals(x, y -1)
		
func refresh_visuals(x, y):
	var stairSpriteIndex = 1;
	
	if isBasement:
		if Global.Building.is_bottom_floor(y):
			stairSpriteIndex = 3
		else:
			stairSpriteIndex = 2
	elif Global.Building.is_top_floor(y):
		stairSpriteIndex = 0
		
	stairsBackgroundSprite.region_rect = Rect2(0, GRID_SIZE * stairSpriteIndex, GRID_SIZE, GRID_SIZE)
	stairsForegroundSprite.region_rect = Rect2(GRID_SIZE, GRID_SIZE * stairSpriteIndex, GRID_SIZE, GRID_SIZE)

static func custom_placement_check(location) -> bool:
	
	if not Global.Building.has_any_rooms_on_x(location.x):
		return true
		
	if Global.Building.get_room_from_index(location + Vector2i.UP) is RoomStairs:
		return true
		
	if Global.Building.get_room_from_index(location + Vector2i.DOWN) is RoomStairs:
		return true
		
	return false
