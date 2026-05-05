extends Node2D

@onready var _tiles_walls : TileMapLayer = $ForegroundTiles
@onready var _tiles_roof : TileMapLayer = $RoofTiles
@onready var _roof_decorations: Node2D = $RoofDecorations
@onready var _sign: BuildingSign = $SaloonSign
@onready var infrastructure = $Infrastructure

var floors = {}
var query : BuildingRoomQueries
var _tile_renderer : BuildingTileRenderer
var _roof_stove_pipes_by_x: Dictionary = {}
const FLOOR_POSITION_Y_BIAS := -1.0
const ROOF_STOVE_PIPE_SCENE := preload("res://scenes/building_roof_stove_pipe.tscn")
const ROOF_STOVE_PIPE_Y_OFFSET := 26.0

# RoomData resources
const room_data_empty := preload("res://assets/resources/rooms/room_empty.tres")
const room_data_junk := preload("res://assets/resources/rooms/room_junk.tres")
const room_data_stairs := preload("res://assets/resources/rooms/room_stairs.tres")
const room_data_brewery := preload("res://assets/resources/rooms/room_brewery.tres")
const room_data_storage := preload("res://assets/resources/rooms/room_storage.tres")
const room_data_bath := preload("res://assets/resources/rooms/room_bath.tres")
const room_data_toilet := preload("res://assets/resources/rooms/room_toilet.tres")
const room_data_bar := preload("res://assets/resources/rooms/room_bar.tres")
const room_data_entertainment := preload("res://assets/resources/rooms/room_entertainment.tres")
const room_data_table := preload("res://assets/resources/rooms/room_table.tres")
const room_data_bed := preload("res://assets/resources/rooms/room_bed.tres")
const room_data_well := preload("res://assets/resources/rooms/room_well.tres")
const room_data_outhouse := preload("res://assets/resources/rooms/room_outhouse.tres")
const room_data_destillery := preload("res://assets/resources/rooms/room_destillery.tres")
const room_data_aging_cellar := preload("res://assets/resources/rooms/room_aging_cellar.tres")
const room_data_prison := preload("res://assets/resources/rooms/room_prison.tres")
const room_data_bounty_board := preload("res://assets/resources/rooms/room_bounty_board.tres")
const room_data_safe := preload("res://assets/resources/rooms/room_safe.tres")
const room_data_horse_post := preload("res://assets/resources/rooms/room_horse_post.tres")
const room_data_broom_closet := preload("res://assets/resources/rooms/room_broom_closet.tres")
const room_data_bouncer := preload("res://assets/resources/rooms/room_bouncer.tres")
const room_data_water_tower := preload("res://assets/resources/rooms/room_water_tower.tres")
const room_data_gambling := preload("res://assets/resources/rooms/room_gambling.tres")
const room_data_trading_office := preload("res://assets/resources/rooms/room_trading_office.tres")
const infrastructure_data_water_pipe := preload("res://assets/resources/infrastructure/infrastructure_water_pipe.tres")
const infrastructure_data_stove := preload("res://assets/resources/infrastructure/infrastructure_stove.tres")

func _ready():
	query = BuildingRoomQueries.new(self)
	_tile_renderer = BuildingTileRenderer.new(_tiles_walls, _tiles_roof)
	if is_instance_valid(infrastructure) and not infrastructure.on_infrastructure_changed_signal.is_connected(_on_infrastructure_changed):
		infrastructure.on_infrastructure_changed_signal.connect(_on_infrastructure_changed)

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
	_erase_room_cell(room.x, room.y)
	infrastructure.clear_under_room(room)
	update_foreground_tiles()
	GlobalEventHandler.on_room_deleted_signal.emit(room)
	room.destroy()

func replace_with_empty(room: RoomBase):
	set_room(room_data_empty, room.x, room.y)
	infrastructure.clear_under_room(room)
	refresh_adjacent_stair_visuals(room.x, room.y, room.data.width, room.data.height)
	update_foreground_tiles()
	GlobalEventHandler.on_room_deleted_signal.emit(room)
	room.destroy()

func delete_room(room: RoomBase):
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
	infrastructure.clear_under_room(room)
	refresh_adjacent_stair_visuals(room.x, room.y, room.data.width, room.data.height)
	update_foreground_tiles()
	GlobalEventHandler.on_room_deleted_signal.emit(room)
	room.destroy()

func refresh_adjacent_stair_visuals(x: int, y: int, width: int, height: int) -> void:
	for col in width:
		var nx = x + col
		var stair_below: RoomStairs = get_room_from_index(Vector2i(nx, y - 1)) as RoomStairs
		if stair_below != null:
			stair_below.refresh_visuals()
		var stair_above: RoomStairs = get_room_from_index(Vector2i(nx, y + height)) as RoomStairs
		if stair_above != null:
			stair_above.refresh_visuals()

func update_foreground_tiles():
	_tile_renderer.update(floors)
	if is_instance_valid(infrastructure):
		infrastructure.refresh_visuals()
	_update_sign_position()
	_update_roof_stove_pipes()

func _update_sign_position():
	var idx: Vector2i = _tile_renderer.sign_room_index
	if idx.x == -9999:
		_sign.visible = false
		return
	# Center of the sign tile in Building-local space
	var sign_pos: Vector2 = Vector2(idx.x * 48 + 24, _tiles_roof.position.y + (-idx.y - 1) * 48 + 24)
	_sign.set_target_position(sign_pos)

func _on_infrastructure_changed(layer_name: StringName) -> void:
	if layer_name == BuildingInfrastructure.STOVE_LAYER:
		_update_roof_stove_pipes()

func _update_roof_stove_pipes() -> void:
	if _tile_renderer == null or not is_instance_valid(infrastructure):
		return

	var active_columns := {}
	for column_x in infrastructure.get_layer_columns(BuildingInfrastructure.STOVE_LAYER):
		if not _tile_renderer.roof_room_index_by_x.has(column_x):
			continue
		active_columns[column_x] = true

		var pipe := _roof_stove_pipes_by_x.get(column_x, null) as Node2D
		if not is_instance_valid(pipe):
			pipe = ROOF_STOVE_PIPE_SCENE.instantiate() as Node2D
			_roof_decorations.add_child(pipe)
			_roof_stove_pipes_by_x[column_x] = pipe

		pipe.position = _get_roof_stove_pipe_position(column_x)

	for column_x in _roof_stove_pipes_by_x.keys():
		if active_columns.has(column_x):
			continue
		var stale_pipe := _roof_stove_pipes_by_x[column_x] as Node2D
		if is_instance_valid(stale_pipe):
			stale_pipe.queue_free()
		_roof_stove_pipes_by_x.erase(column_x)

func _get_roof_stove_pipe_position(column_x: int) -> Vector2:
	var roof_index: Vector2i = _tile_renderer.roof_room_index_by_x[column_x]
	return Vector2(column_x * 48 + 24, _tiles_roof.position.y + (-roof_index.y - 1) * 48 + ROOF_STOVE_PIPE_Y_OFFSET)

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

func round_floor_index_from_global_position(global_pos: Vector2):
	return round_room_index_from_global_position(global_pos + Vector2(0, FLOOR_POSITION_Y_BIAS))

func global_position_from_room_index(room_index: Vector2i):
	var x = room_index.x * 48 + 24
	var y = room_index.y * -48
	return Vector2(x, y)
