extends RoomBase
class_name RoomMineshaft

const BACKGROUND_BOTH := preload("res://assets/sprites/mineshaft_tunnel_both_background.png")
const BACKGROUND_LEFT := preload("res://assets/sprites/mineshaft_tunnel_left_background.png")
const BACKGROUND_RIGHT := preload("res://assets/sprites/mineshaft_tunnel_right_background.png")
const FOREGROUND_BOTH := preload("res://assets/sprites/mineshaft_tunnel_both_foreground.png")
const FOREGROUND_LEFT := preload("res://assets/sprites/mineshaft_tunnel_left_foreground.png")
const FOREGROUND_RIGHT := preload("res://assets/sprites/mineshaft_tunnel_right_foreground.png")

@onready var background_sprite: Sprite2D = $Background
@onready var foreground_sprite: Sprite2D = $Foreground

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	call_deferred("refresh_tunnel_layout")

func refresh_tunnel_layout() -> void:
	if not is_instance_valid(self):
		return

	var connects_left := _is_mineshaft_family(Building.get_room_from_index(Vector2i(x - 1, y)))
	var connects_right := _is_mineshaft_family(Building.get_room_from_index(Vector2i(x + 1, y)))

	if connects_left and connects_right:
		background_sprite.texture = BACKGROUND_BOTH
		foreground_sprite.texture = FOREGROUND_BOTH
	elif connects_left:
		background_sprite.texture = BACKGROUND_LEFT
		foreground_sprite.texture = FOREGROUND_LEFT
	else:
		background_sprite.texture = BACKGROUND_RIGHT
		foreground_sprite.texture = FOREGROUND_RIGHT

static func _is_mineshaft_family(room) -> bool:
	return room is RoomMineshaft or room is RoomMineshaftEntrance
