extends Node2D
class_name Building

@onready var _tiles_walls : TileMapLayer = $ForegroundTiles
@onready var _tiles_roof : TileMapLayer = $RoofTiles

var floors = {}
var query : BuildingRoomQueries
var _tile_renderer : BuildingTileRenderer

# RoomData resources
const room_data_empty := preload("res://assets/resources/room_empty.tres")
const room_data_junk := preload("res://assets/resources/room_junk.tres")
const room_data_stairs := preload("res://assets/resources/room_stairs.tres")
const room_data_brewery := preload("res://assets/resources/room_brewery.tres")
const room_data_storage := preload("res://assets/resources/room_storage.tres")
const room_data_bath := preload("res://assets/resources/room_bath.tres")
const room_data_bar := preload("res://assets/resources/room_bar.tres")
const room_data_table := preload("res://assets/resources/room_table.tres")
const room_data_well := preload("res://assets/resources/room_well.tres")
const room_data_outhouse := preload("res://assets/resources/room_outhouse.tres")
const room_data_destillery := preload("res://assets/resources/room_destillery.tres")
const room_data_aging_cellar := preload("res://assets/resources/room_aging_cellar.tres")
const room_data_prison := preload("res://assets/resources/room_prison.tres")
const room_data_bounty_board := preload("res://assets/resources/room_bounty_board.tres")

func _init():
	Global.Building = self

func _ready():
	query = BuildingRoomQueries.new(self)
	_tile_renderer = BuildingTileRenderer.new(_tiles_walls, _tiles_roof)

func set_room(data: RoomData, x: int, y: int, auto_initialize = true):
	var scene = data.packed_scene
	var instance = scene.instantiate() as RoomBase
	instance.data = data
	add_child(instance)
	instance.position = Vector2(x * 48, y * -48)

	if floors.is_empty():
		floors = { y: { x: instance } }
	elif not floors.has(y):
		floors[y] = { x: instance }
	else:
		floors[y][x] = instance

	if auto_initialize:
		instance.init_room(x, y)

	GlobalEventHandler.on_room_created_signal.emit(instance)

func initialize_all_rooms():
	for y in floors.keys():
		for x in floors[y].keys():
			floors[y][x].init_room(x, y)

func delete_room(room: RoomBase):
	GlobalEventHandler.on_room_deleted_signal.emit(room)
	set_room(room_data_empty, room.x, room.y)
	room.destroy()

func update_foreground_tiles():
	_tile_renderer.update(floors)

func get_room_from_index(index: Vector2i):
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

func is_bottom_floor(y: int):
	if floors.is_empty():
		return false
	var floor_indexes = floors.keys()
	floor_indexes.sort()
	return floor_indexes[0] == y

func is_top_floor(y: int):
	if floors.is_empty():
		return false
	var floor_indexes = floors.keys()
	floor_indexes.sort()
	return floor_indexes[len(floor_indexes) - 1] == y

func count_rooms_by_data(data: RoomData):
	var count = 0
	for y in floors:
		for x in floors[y]:
			var room = floors[y][x] as RoomBase
			if room.data == data:
				count += 1
	return count

func round_room_index_from_global_position(global_pos: Vector2):
	var x = floor((global_pos.x - 24) / 48)
	var y = floor(global_pos.y / -48)
	return Vector2i(x, y)

func global_position_from_room_index(room_index: Vector2i):
	var x = room_index.x * 48 + 24
	var y = room_index.y * -48
	return Vector2(x, y)
