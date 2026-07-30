extends RoomTable
class_name RoomSaloon

const CHANDELIER_TEXTURE := preload("res://assets/sprites/room_saloon_custom_light_overlay.png")
const CHANDELIER_POSITION := Vector2(48.0, -48.0)
const CHANDELIER_TINT := Color(1.0, 0.74, 0.38, 1.0)
const CHANDELIER_INTENSITY := 2.0


func _ready() -> void:
	call_deferred("_register_chandelier_overlay")


func _exit_tree() -> void:
	RoomTemperatureOverlayHandler.unregister_light_input(self)


func _register_chandelier_overlay() -> void:
	RoomTemperatureOverlayHandler.register_light_input(
		self,
		self,
		CHANDELIER_TEXTURE,
		global_position + CHANDELIER_POSITION,
		CHANDELIER_TINT,
		CHANDELIER_INTENSITY
	)

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
