extends RoomBase
class_name RoomMineshaft

const BACKGROUND_BOTH := preload("res://assets/sprites/mineshaft_tunnel_both_background.png")
const BACKGROUND_LEFT := preload("res://assets/sprites/mineshaft_tunnel_left_background.png")
const BACKGROUND_RIGHT := preload("res://assets/sprites/mineshaft_tunnel_right_background.png")
const FOREGROUND_BOTH := preload("res://assets/sprites/mineshaft_tunnel_both_foreground.png")
const FOREGROUND_LEFT := preload("res://assets/sprites/mineshaft_tunnel_left_foreground.png")
const FOREGROUND_RIGHT := preload("res://assets/sprites/mineshaft_tunnel_right_foreground.png")
const _LEFT_DUG_X_RANGE := Vector2i(4, 22)
const _RIGHT_DUG_X_RANGE := Vector2i(26, 44)

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

func get_random_dug_floor_position() -> Vector2:
	var dug_ranges := _get_dug_x_ranges()
	if dug_ranges.is_empty():
		return get_random_floor_position()

	var x_range: Vector2i = dug_ranges.pick_random()
	return global_position + Vector2(randi_range(x_range.x, x_range.y), 0.0)

func _get_dug_x_ranges() -> Array[Vector2i]:
	var dug_ranges: Array[Vector2i] = []
	if _is_mineshaft_family(Building.get_room_from_index(Vector2i(x - 1, y))):
		dug_ranges.append(_LEFT_DUG_X_RANGE)
	if _is_mineshaft_family(Building.get_room_from_index(Vector2i(x + 1, y))):
		dug_ranges.append(_RIGHT_DUG_X_RANGE)
	return dug_ranges

static func _is_mineshaft_family(room) -> bool:
	return room is RoomMineshaft or room is RoomMineshaftEntrance
