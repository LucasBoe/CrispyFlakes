extends Sprite2D
class_name FloorDirtMess

const FRAME_SIZE := Vector2i(12, 6)
const FRAME_COUNT := 5
const FRONT_NPC_Z_INDEX := Enum.ZLayer.NPC_DEFAULT + 2
const FLOOR_OFFSET := Vector2(0, -2)
const STINK_OFFSET := Vector2(0, -3)
const FLY_OFFSET := Vector2(0, -4)

func _ready() -> void:
	z_index = FRONT_NPC_Z_INDEX
	offset = FLOOR_OFFSET
	region_enabled = true
	region_rect = Rect2i(randi_range(0, FRAME_COUNT - 1) * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
	flip_h = randf() < 0.5

func get_stink_anchor_global_position() -> Vector2:
	return to_global(STINK_OFFSET)

func get_fly_anchor_global_position() -> Vector2:
	return to_global(FLY_OFFSET)
