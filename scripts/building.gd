extends Node2D

class_name Building

@onready var tilesWalls : TileMapLayer = $ForegroundTiles
@onready var tilesRoof : TileMapLayer = $RoofTiles

var floors = {}

const room_empty: PackedScene = preload("res://scenes/rooms/room_empty.tscn")
const room_junk: PackedScene = preload("res://scenes/rooms/room_junk.tscn")
const room_stairs: PackedScene = preload("res://scenes/rooms/room_stairs.tscn")
const room_brewery: PackedScene = preload("res://scenes/rooms/room_brewery.tscn")
const room_buttery: PackedScene = preload("res://scenes/rooms/room_buttery.tscn")
const room_bath: PackedScene = preload("res://scenes/rooms/room_bath.tscn")
const room_bar_water: PackedScene = preload("res://scenes/rooms/room_bar_water.tscn")
const room_bar_beer: PackedScene = preload("res://scenes/rooms/room_bar_beer.tscn")
const room_bar_wiskey: PackedScene = preload("res://scenes/rooms/room_bar_wiskey.tscn")
const room_table: PackedScene = preload("res://scenes/rooms/room_table.tscn")
const room_well: PackedScene = preload("res://scenes/rooms/room_well.tscn")

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
	Global.Building = self
	
	set_room(room_empty, -2,0, false)
	set_room(room_bar_water, -1,0, false)
	set_room(room_stairs, 0,0, false)
	set_room(room_well, 4,0, false)
	set_room(room_stairs, 0,-1, false)
	set_room(room_junk, -1,-1, false)
	
	InitalizeAllRooms()
	update_foreground_tiles()

func set_room(scene : PackedScene, x : int, y : int, autoInitialize = true):
	var instance = scene.instantiate();
	#instance.name = str("room_", x, "_", y)
	add_child(instance)
	instance.position = Vector2(x * 48, y * -48)
	
	if floors.is_empty():
		floors = { y : { x : instance }}
	elif floors.has(y):
		floors[y][x] = instance;
	else:
		floors[y] = { x : instance }
		
	if autoInitialize:
		instance.InitRoom(x,y)

func InitalizeAllRooms():
	for y in floors.keys():
		for x in floors[y].keys():
			floors[y][x].InitRoom(x,y)
			
func delete_room(room : RoomBase):
	set_room(room_empty, room.x, room.y)
	RoomHighlighter.end_request(room)
	room.queue_free()
	
func update_foreground_tiles():
	
	tilesWalls.clear()
	
	var listOfXPositions = []
	var listOfRoomIndexesOnFloor = {}
	var maxFloorHeightAtX = {}
	var maxFloorLevel = -1;
	var triplets = []
	
	for y in floors.keys():
		listOfRoomIndexesOnFloor[y] = []
		
		maxFloorLevel = max(maxFloorLevel, y)
		
		for x in floors[y].keys():
			
			#skip all rooms that are outside rooms
			if floors[y][x].isOutsideRoom:
				continue
			
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
		
		var previousLevel = compare_level.call(maxFloorHeightAtX, x, - 1)
		var nextLevel = compare_level.call(maxFloorHeightAtX, x, + 1)
			
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
	
	if len(triplets) > 0:
		var index = triplets[(len(triplets) - 1)/2]
		var x = index.x
		var y = index.y
		
		set_roof(x-1,y, -1, true)
		set_roof(x, y, roofIndexMap.SIGN)
		set_roof(x+1,y, -1, true)	
		
func compare_level(floorHeightsOverX : Dictionary, x : int, offset : int):

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
		
func set_wall(x : int, y : int, context : int = -1):
	tilesWalls.set_cell(Vector2i(x,y*-1 -1), 1 if y < 0 else 0, Vector2i(context,0))
	
func set_roof(x : int, y : int, context : int = -1, clear : bool = false):
	
	var cords = Vector2i(x, y*-1 -1)
	
	if (context >= 0):
		tilesRoof.set_cell(cords, 1 if y < 0 else 0, Vector2i(context,0))
	elif clear:
		tilesRoof.erase_cell(cords)
		
func get_room_from_index(index : Vector2i):
	if floors.has(index.y):
		if floors[index.y].has(index.x):
			return floors[index.y][index.x]
			
	return null
	
func has_any_rooms_on_x(xx):
	for y in floors.keys():
		for x in floors[y]:
			if x == xx:
				return true
	return false
	
func get_current_room_from_global_position(global_pos : Vector2):
	var listOfAllRooms = []
	for y in floors.keys():
		for x in floors[y]:
			listOfAllRooms.append(floors[y][x])
			
	var closestRoom
	var shortest_distance: float = sqrt(pow(24,2)*2)

	for room in listOfAllRooms:
		var distance = room.get_center_position().distance_to(global_pos)
		if distance < shortest_distance:
			shortest_distance = distance
			closestRoom = room
	
	return closestRoom
	
func round_room_index_from_global_position(global_pos : Vector2):
	var x = floor((global_pos.x -24) / 48)
	var y = floor(global_pos.y / -48)
	return Vector2i(x,y)
	
func global_position_from_room_index(room_index : Vector2i):
	var x = room_index.x * 48 + 24
	var y = room_index.y * -48
	return Vector2(x,y)

func is_bottom_floor(y : int):
	if floors.is_empty():
		return false
		
	var floorIndexes = floors.keys()
	floorIndexes.sort()
	return floorIndexes[0] == y

func is_top_floor(y : int):
	if floors.is_empty():
		return false
		
	var floorIndexes = floors.keys()
	floorIndexes.sort()
	return floorIndexes[len(floorIndexes)-1] == y
	
func get_closest_room_of_type_on_floor(type, global_pos : Vector2, y):
	var closestRoom
	var shortest_distance: float = INF

	for x in floors[y]:
		var room = floors[y][x]
		
		if room:
			pass
			
		if room is not RoomBase:
			continue
			
		if not is_instance_of(room, type):
			continue
			
		var distance = room.global_position.distance_to(global_pos)
		if distance < shortest_distance:
			shortest_distance = distance	
			closestRoom = room
	
	return closestRoom
		
func get_closest_room_of_type(type, global_pos : Vector2, blacklist = null):
	var closestRoom
	var shortest_distance: float = INF

	for y in floors:
		for x in floors[y]:
			var room = floors[y][x]
					
			if room:
				pass
				
			if room is not RoomBase:
				continue
				
			if not is_instance_of(room, type):
				continue
				
			if blacklist != null and blacklist.has(room):
				continue
				
			var distance = room.global_position.distance_to(global_pos - Vector2(24,0))
			if distance < shortest_distance:
				shortest_distance = distance	
				closestRoom = room
	
	return closestRoom

func get_all_rooms_of_type(type):
	var rooms = []
	for y in floors:
		for x in floors[y]:
			var room = floors[y][x]
						
			if room:
				pass
					
			if room is not RoomBase:
				continue
					
			if not is_instance_of(room, type):
				continue
				
			rooms.append(room)
		
	return rooms
