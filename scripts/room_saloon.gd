extends RoomTable
class_name RoomSaloon

func get_random_floor_position():
	return global_position + Vector2(randi_range(8, 88), 0)

func get_center_position():
	return global_position + Vector2(48, -48)

func get_top_center_position():
	return global_position + Vector2(48, -96)

func get_center_floor_position():
	return global_position + Vector2(48, 0)

func get_notification_position():
	return global_position + Vector2(26, -56)
