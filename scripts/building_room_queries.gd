extends RefCounted
class_name BuildingRoomQueries

var _building : Building

func _init(_b: Building) -> void:
	_building = _b

func all_rooms_of_type(type, reachable_rooms: Array = []) -> Array:
	var rooms = []
	for y in _building.floors:
		for x in _building.floors[y]:
			var room = _building.floors[y][x]
			if room is not RoomBase or not is_instance_of(room, type):
				continue
			rooms.append(room)

	if reachable_rooms.is_empty():
		return rooms

	var filtered = rooms.filter(func(r): return r in reachable_rooms)
	return filtered if not filtered.is_empty() else rooms

func closest_room_of_type(type, global_pos: Vector2, blacklist = null, offset = Vector2.ZERO, reachable_rooms: Array = []):
	var closest_reachable = null
	var closest_any = null
	var dist_reachable := INF
	var dist_any := INF

	for y in _building.floors:
		for x in _building.floors[y]:
			var room = _building.floors[y][x]
			if room is not RoomBase or not is_instance_of(room, type):
				continue
			if blacklist != null and blacklist.has(room):
				continue

			var d = room.global_position.distance_to(global_pos + offset)
			if d < dist_any:
				dist_any = d
				closest_any = room
			if not reachable_rooms.is_empty() and room in reachable_rooms and d < dist_reachable:
				dist_reachable = d
				closest_reachable = room

	return closest_reachable if closest_reachable != null else closest_any

func rooms_of_type_ordered_by_distance(type, global_pos: Vector2, blacklist = null, reachable_rooms: Array = []) -> Array:
	var reachable_result = []
	var any_result = []

	for y in _building.floors:
		for x in _building.floors[y]:
			var room = _building.floors[y][x]
			if room == null or room is not RoomBase or not is_instance_of(room, type):
				continue
			if blacklist != null and blacklist.has(room):
				continue

			var d = room.global_position.distance_to(global_pos)
			any_result.append({ "room": room, "dist": d })
			if not reachable_rooms.is_empty() and room in reachable_rooms:
				reachable_result.append({ "room": room, "dist": d })

	var result = reachable_result if not reachable_result.is_empty() else any_result
	result.sort_custom(func(a, b): return a["dist"] < b["dist"])

	var ordered: Array = []
	for entry in result:
		ordered.append(entry["room"])
	return ordered

func closest_on_floor(type, global_pos: Vector2, y):
	var closest_room = null
	var shortest_distance: float = INF

	for x in _building.floors[y]:
		var room = _building.floors[y][x]
		if room is not RoomBase or not is_instance_of(room, type):
			continue
		var distance = room.global_position.distance_to(global_pos)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_room = room

	return closest_room

func room_at_position(global_pos: Vector2):
	var closest_room = null
	var shortest_distance: float = sqrt(pow(24, 2) * 2)

	for y in _building.floors.keys():
		for x in _building.floors[y]:
			var room = _building.floors[y][x]
			var distance = room.get_center_position().distance_to(global_pos)
			if distance < shortest_distance:
				shortest_distance = distance
				closest_room = room

	return closest_room
