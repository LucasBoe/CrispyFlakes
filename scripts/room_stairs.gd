extends RoomEmpty
class_name RoomStairs

const GRID_SIZE = 48

@onready var stairsBackgroundSprite = $"Stairs-Background"
@onready var stairsForegroundSprite = $"Stairs-Foreground"

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
		
	
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
