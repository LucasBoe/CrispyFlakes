extends Node2D

@onready var _tiles_walls : TileMapLayer = $ForegroundTiles
@onready var _tiles_roof : TileMapLayer = $RoofTiles
@onready var _sign: BuildingSign = $SaloonSign

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
const room_data_entertainment := preload("res://assets/resources/room_entertainment.tres")
const room_data_table := preload("res://assets/resources/room_table.tres")
const room_data_bed := preload("res://assets/resources/room_bed.tres")
const room_data_well := preload("res://assets/resources/room_well.tres")
const room_data_outhouse := preload("res://assets/resources/room_outhouse.tres")
const room_data_destillery := preload("res://assets/resources/room_destillery.tres")
const room_data_aging_cellar := preload("res://assets/resources/room_aging_cellar.tres")
const room_data_prison := preload("res://assets/resources/room_prison.tres")
const room_data_bounty_board := preload("res://assets/resources/room_bounty_board.tres")
const room_data_safe := preload("res://assets/resources/room_safe.tres")
const room_data_horse_post := preload("res://assets/resources/room_horse_post.tres")
const room_data_broom_closet := preload("res://assets/resources/room_broom_closet.tres")
const room_data_bouncer := preload("res://assets/resources/room_bouncer.tres")
const room_data_water_tower := preload("res://assets/resources/room_water_tower.tres")
const room_data_gambling := preload("res://assets/resources/room_gambling.tres")

func _ready():
	query = BuildingRoomQueries.new(self)
	_tile_renderer = BuildingTileRenderer.new(_tiles_walls, _tiles_roof)

func set_room(data: RoomData, x: int, y: int, auto_initialize = true):
	var scene = data.packed_scene
	var instance = scene.instantiate() as RoomBase
	instance.data = data
	add_child(instance)
	instance.position = Vector2(x * 48, y * -48)

	for col in data.width:
		for row in data.height:
			var fx = x + col
			var fy = y + row
			if not floors.has(fy):
				floors[fy] = {}
			floors[fy][fx] = instance

	if auto_initialize:
		instance.init_room(x, y)

	GlobalEventHandler.on_room_created_signal.emit(instance)

func initialize_all_rooms():
	for y in floors.keys():
		for x in floors[y].keys():
			floors[y][x].init_room(x, y)

func erase_empty(room: RoomBase):
	GlobalEventHandler.on_room_deleted_signal.emit(room)
	_erase_room_cell(room.x, room.y)
	update_foreground_tiles()
	room.destroy()

func delete_room(room: RoomBase):
	GlobalEventHandler.on_room_deleted_signal.emit(room)
	if room.data != null and room.data.is_outdoor:
		for col in room.data.width:
			for row in room.data.height:
				_erase_room_cell(room.x + col, room.y + row)
	else:
		for col in room.data.width:
			for row in room.data.height:
				var above = get_room_from_index(Vector2i(room.x + col, room.y + row + 1))
				if above == null or above is RoomEmpty:
					_erase_room_cell(room.x + col, room.y + row)
				else:
					set_room(room_data_empty, room.x + col, room.y + row)
	update_foreground_tiles()
	room.destroy()

func update_foreground_tiles():
	_tile_renderer.update(floors)
	_update_sign_position()

func _update_sign_position():
	var idx: Vector2i = _tile_renderer.sign_room_index
	if idx.x == -9999:
		_sign.visible = false
		return
	# Center of the sign tile in Building-local space
	var sign_pos: Vector2 = Vector2(idx.x * 48 + 24, _tiles_roof.position.y + (-idx.y - 1) * 48 + 24)
	_sign.set_target_position(sign_pos)

func _erase_room_cell(x: int, y: int) -> void:
	if not floors.has(y):
		return

	floors[y].erase(x)
	if floors[y].is_empty():
		floors.erase(y)

func get_room_from_index(index: Vector2i):
	if floors.has(index.y):
		if floors[index.y].has(index.x):
			return floors[index.y][index.x]
	return null

func has_any_rooms_on_x(xx : int):
	for y in floors.keys():
		if xx in floors[y]:
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
	var x = floor(global_pos.x / 48)
	var y = floor(global_pos.y / -48)
	return Vector2i(x, y)

func global_position_from_room_index(room_index: Vector2i):
	var x = room_index.x * 48 + 24
	var y = room_index.y * -48
	return Vector2(x, y)
