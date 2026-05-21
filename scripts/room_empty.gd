extends RoomBase
class_name RoomEmpty

static func custom_placement_check(location: Vector2i) -> bool:
	return not (Building.get_room_from_index(location) is RoomEmpty)
