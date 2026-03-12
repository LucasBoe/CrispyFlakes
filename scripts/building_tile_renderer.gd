extends RefCounted
class_name BuildingTileRenderer

var _tiles_walls : TileMapLayer
var _tiles_roof : TileMapLayer

enum levelDifference { SAME, HIGHER, LOWER }
enum placementContext { OUTER_LEFT = 0, LEFT = 1, MIDDLE = 2, RIGHT = 3, OUTER_RIGHT = 4 }
enum roofIndexMap {
	OUTER_LEFT_LOWER = 0,
	RIGHT_END_HIGHER = 1,
	LEFT_END_HIGHER = 2,
	MIDDLE = 3,
	OUTER_RIGHT_LOWER = 4,
	SIGN = 5,
	DOUBLE_END_HIGHER = 6,
}

func _init(walls: TileMapLayer, roof: TileMapLayer) -> void:
	_tiles_walls = walls
	_tiles_roof = roof

func update(floors: Dictionary) -> void:
	_tiles_walls.clear()
	_tiles_roof.clear()

	var list_of_x_positions = []
	var list_of_room_indexes_on_floor = {}
	var max_floor_height_at_x = {}
	var max_floor_level = -1
	var triplets = []

	for y in floors.keys():
		list_of_room_indexes_on_floor[y] = []
		max_floor_level = max(max_floor_level, y)

		for x in floors[y].keys():
			if floors[y][x].is_outside_room:
				continue

			list_of_room_indexes_on_floor[y].append(x)
			list_of_room_indexes_on_floor[y].sort()

			if max_floor_height_at_x.has(x):
				max_floor_height_at_x[x] = max(max_floor_height_at_x[x], y)
			else:
				max_floor_height_at_x[x] = y

			if not list_of_x_positions.has(x):
				list_of_x_positions.append(x)

	for y in floors.keys():
		for x in list_of_room_indexes_on_floor[y]:
			if not list_of_room_indexes_on_floor[y].has(x - 1):
				set_wall(x - 1, y, placementContext.OUTER_LEFT)
				set_wall(x, y, placementContext.LEFT)
			elif not list_of_room_indexes_on_floor[y].has(x + 1):
				set_wall(x + 1, y, placementContext.OUTER_RIGHT)
				set_wall(x, y, placementContext.RIGHT)
			else:
				set_wall(x, y, placementContext.MIDDLE)

	for x in list_of_x_positions:
		var y = max_floor_height_at_x[x]

		var previous_level = _compare_level(max_floor_height_at_x, x, -1)
		var next_level = _compare_level(max_floor_height_at_x, x, +1)

		if y == max_floor_level and previous_level == levelDifference.SAME and next_level == levelDifference.SAME:
			triplets.append(Vector2i(x, y))

		var own_roof_index = roofIndexMap.MIDDLE

		if previous_level == levelDifference.LOWER:
			set_roof(x - 1, y, roofIndexMap.OUTER_LEFT_LOWER)
		elif previous_level == levelDifference.HIGHER:
			own_roof_index = roofIndexMap.LEFT_END_HIGHER

		if next_level == levelDifference.LOWER:
			set_roof(x + 1, y, roofIndexMap.OUTER_RIGHT_LOWER)
		elif next_level == levelDifference.HIGHER:
			if previous_level == levelDifference.HIGHER:
				own_roof_index = roofIndexMap.DOUBLE_END_HIGHER
			else:
				own_roof_index = roofIndexMap.RIGHT_END_HIGHER

		set_roof(x, y, own_roof_index)

	if len(triplets) > 0:
		var index = triplets[(len(triplets) - 1) / 2]
		var x = index.x
		var y = index.y

		set_roof(x - 1, y, -1, true)
		set_roof(x, y, roofIndexMap.SIGN)
		set_roof(x + 1, y, -1, true)

func set_wall(x: int, y: int, context: int = -1) -> void:
	_tiles_walls.set_cell(Vector2i(x, y * -1 - 1), 1 if y < 0 else 0, Vector2i(context, 0))

func set_roof(x: int, y: int, context: int = -1, clear: bool = false) -> void:
	var cords = Vector2i(x, y * -1 - 1)
	if context >= 0:
		_tiles_roof.set_cell(cords, 1 if y < 0 else 0, Vector2i(context, 0))
	elif clear:
		_tiles_roof.erase_cell(cords)

func _compare_level(floor_heights_over_x: Dictionary, x: int, offset: int):
	if not floor_heights_over_x.has(x + offset):
		return levelDifference.LOWER

	var y = floor_heights_over_x[x]
	var other_y = floor_heights_over_x[x + offset]

	if y == other_y:
		return levelDifference.SAME
	elif y > other_y:
		return levelDifference.LOWER
	else:
		return levelDifference.HIGHER
