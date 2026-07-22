extends RoomBase
class_name RoomElevator

func get_cage_stop_position() -> Vector2:
	return get_center_floor_position()

func get_boarding_position() -> Vector2:
	return get_center_floor_position() + Vector2(-12.0, 0.0)

func get_exit_position() -> Vector2:
	return get_center_floor_position() + Vector2(12.0, 0.0)
