extends RoomEmpty

class_name RoomStairs

@onready var stairsSprite = $Stairs

func InitRoom(x : int, y : int):
	super.InitRoom(x,y)
		
	
	var stairSpriteIndex = 1;
	
	if isBasement:
		if Global.building.is_bottom_floor(y):
			stairSpriteIndex = 3
		else:
			stairSpriteIndex = 2
	elif Global.building.is_top_floor(y):
		stairSpriteIndex = 0
		
	stairsSprite.region_rect = Rect2(0, 48 * stairSpriteIndex, 48, 48)
	
	print(stairSpriteIndex)
