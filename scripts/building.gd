extends Node2D

@onready var tilesWalls : TileMapLayer = $ForegroundTiles
@onready var tilesRoof : TileMapLayer = $RoofTiles

var floors = {}

const room_empty: PackedScene = preload("res://scenes/room.tscn")

enum levelDifference {
	SAME,
	HIGHER,
	LOWER,
}

enum placementContext {
	OUTER_LEFT = 0,
	LEFT = 1,
	MIDDLE = 2,
	RIGHT = 3,
	OUTER_RIGHT = 4
}

enum roofIndexMap {
	OUTER_LEFT_LOWER = 0,
	RIGHT_END_HIGHER = 1,
	LEFT_END_HIGHER = 2,
	MIDDLE = 3,
	OUTER_RIGHT_LOWER = 4,
	SIGN = 5,
	DOUBLE_END_HIGHER = 6,
}

func _ready():
	set_room(room_empty, -1,0)
	set_room(room_empty, 0,0)
	set_room(room_empty, 1,0)
	set_room(room_empty, 2,0)
	set_room(room_empty, 3,0)
	set_room(room_empty, 0,1)
	set_room(room_empty, 1,1)
	set_room(room_empty, 2,1)
	set_room(room_empty, 0,-1)
	set_room(room_empty, 1,-1)
	set_room(room_empty, 2,-1)
	update_foreground_tiles()

func set_room(scene : PackedScene, x : int, y : int):
	var instance = room_empty.instantiate();
	add_child(instance)
	instance.position = Vector2(x * 48, y * -48)
	
	if floors.is_empty():
		floors = { y : { x : instance }}
	elif floors.has(y):
		floors[y][x] = instance;
	else:
		floors[y] = { x : instance }

func update_foreground_tiles():
	
	tilesWalls.clear()
	
	var listOfXPositions = []
	var listOfRoomIndexesOnFloor = {}
	var maxFloorHeightAtX = {}
	var maxFloorLevel = -1;
	var triplets = []
	
	var CompareLevel = func(floorHeightsOverX : Dictionary, x : int, offset : int):
		
		if not floorHeightsOverX.has(x + offset):
			return levelDifference.LOWER
		
		var y = floorHeightsOverX[x]
		var otherY = floorHeightsOverX[x + offset]
		
		if y == otherY:
			return levelDifference.SAME
		elif y > otherY:
			return levelDifference.LOWER
		else:
			return levelDifference.HIGHER
	
	for y in floors.keys():
		listOfRoomIndexesOnFloor[y] = []
		
		maxFloorLevel = max(maxFloorLevel, y)
		
		for x in floors[y].keys():
			listOfRoomIndexesOnFloor[y].append(x)
			listOfRoomIndexesOnFloor[y].sort()
			
			if maxFloorHeightAtX.has(x):
				maxFloorHeightAtX[x] = max(maxFloorHeightAtX[x], y)
			else:
				maxFloorHeightAtX[x] = y
			
			if not listOfXPositions.has(x):
				listOfXPositions.append(x)
	
	for y in floors.keys():
		for x in listOfRoomIndexesOnFloor[y]:
			if not listOfRoomIndexesOnFloor[y].has(x-1):
				set_wall(x-1, y, placementContext.OUTER_LEFT);
				set_wall(x, y, placementContext.LEFT);
			elif not listOfRoomIndexesOnFloor[y].has(x+1):
				set_wall(x+1, y, placementContext.OUTER_RIGHT);
				set_wall(x, y, placementContext.RIGHT);
			else:
				set_wall(x, y, placementContext.MIDDLE);			
	
	for x in listOfXPositions:
		var y = maxFloorHeightAtX[x];
		
		var previousLevel = CompareLevel.call(maxFloorHeightAtX, x, - 1)
		var nextLevel = CompareLevel.call(maxFloorHeightAtX, x, + 1)
			
		if y == maxFloorLevel and previousLevel == levelDifference.SAME and nextLevel == levelDifference.SAME:
			triplets.append(Vector2i(x,y))
			
		var ownRoofIndex = roofIndexMap.MIDDLE
		
		if previousLevel == levelDifference.LOWER:
			set_roof(x-1,y, roofIndexMap.OUTER_LEFT_LOWER)
		elif previousLevel == levelDifference.HIGHER:
			ownRoofIndex = roofIndexMap.LEFT_END_HIGHER
			
		if nextLevel == levelDifference.LOWER:
			set_roof(x+1, y, roofIndexMap.OUTER_RIGHT_LOWER)
		elif nextLevel == levelDifference.HIGHER:
			if previousLevel == levelDifference.HIGHER:
				ownRoofIndex = roofIndexMap.DOUBLE_END_HIGHER
			else:
				ownRoofIndex = roofIndexMap.RIGHT_END_HIGHER
				
		set_roof(x,y, ownRoofIndex)	
	
	print(triplets)	
	if len(triplets) > 0:
		var index = triplets[(len(triplets) - 1)/2]
		var x = index.x
		var y = index.y
		
		set_roof(x-1,y, -1, true)
		set_roof(x, y, roofIndexMap.SIGN)
		set_roof(x+1,y, -1, true)	
		
func set_wall(x : int, y : int, context : int = -1):
	tilesWalls.set_cell(Vector2i(x,y*-1 -1), 1 if y < 0 else 0, Vector2i(context,0))
	
func set_roof(x : int, y : int, context : int = -1, clear : bool = false):
	
	var cords = Vector2i(x, y*-1 -1)
	
	if (context >= 0):
		tilesRoof.set_cell(cords, 1 if y < 0 else 0, Vector2i(context,0))
	elif clear:
		tilesRoof.erase_cell(cords)
	
