extends RoomBase
class_name RoomDigging

const HORIZONTAL_FRAME_COUNT := 12
const DOWNWARD_FRAME_COUNT := 8
const HORIZONTAL_BACKGROUND := preload("res://assets/sprites/digging_spritesheet_background.png")
const HORIZONTAL_FOREGROUND := preload("res://assets/sprites/digging_spritesheet_foreground.png")
const DOWNWARD_BACKGROUND := preload("res://assets/sprites/digging_down_spritesheet_background.png")
const DOWNWARD_FOREGROUND := preload("res://assets/sprites/digging_down_spritesheet_foreground.png")

enum DigVariant {
	HORIZONTAL,
	DOWNWARD,
}

@onready var background_sprite: Sprite2D = $Background
@onready var foreground_sprite: Sprite2D = $Foreground
@onready var progress_bar: TextureProgressBar = $ProgressBar

var dig_direction := -1.0
var dig_variant := DigVariant.HORIZONTAL
var frame_count := HORIZONTAL_FRAME_COUNT

func init_room(_x: int, _y: int):
	is_outside_room = true
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.DIGGING
	_refresh_dig_layout()
	set_dig_progress(0.0)

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func set_dig_progress(progress: float) -> void:
	var frame_index: int = clampi(floori(progress * float(frame_count - 1)), 0, frame_count - 1)
	background_sprite.frame = frame_index
	foreground_sprite.frame = frame_index
	progress_bar.max_value = 100.0
	progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	progress_bar.visible = progress > 0.0 and progress < 1.0

func get_dig_start_position() -> Vector2:
	if is_digging_down():
		return global_position + Vector2(24, -48)
	if dig_direction > 0.0:
		return global_position + Vector2(-12, 0)
	return global_position + Vector2(60, 0)

func get_dig_end_position() -> Vector2:
	if is_digging_down():
		return global_position + Vector2(24, 0)
	if dig_direction > 0.0:
		return global_position + Vector2(32, 0)
	return global_position + Vector2(16, 0)

func get_assignment_anchor_room() -> RoomBase:
	if not is_digging_down():
		return self

	var room_above := Building.get_room_from_index(Vector2i(x, y + 1)) as RoomBase
	return room_above if _is_existing_room(room_above) else null

func get_dig_animation_direction() -> Vector2:
	if is_digging_down():
		return Vector2.DOWN
	return Vector2.RIGHT if dig_direction > 0.0 else Vector2.LEFT

func is_digging_down() -> bool:
	return dig_variant == DigVariant.DOWNWARD

func _refresh_dig_layout() -> void:
	var left_room := Building.get_room_from_index(Vector2i(x - 1, y)) as RoomBase
	var right_room := Building.get_room_from_index(Vector2i(x + 1, y)) as RoomBase
	var room_above := Building.get_room_from_index(Vector2i(x, y + 1)) as RoomBase
	var left_is_source := _is_existing_basement_room(left_room)
	var right_is_source := _is_existing_basement_room(right_room)
	var has_side_source := left_is_source or right_is_source
	var has_room_above := _is_existing_room(room_above)

	if has_room_above and not has_side_source:
		dig_variant = DigVariant.DOWNWARD
		dig_direction = 0.0
		frame_count = DOWNWARD_FRAME_COUNT
		background_sprite.texture = DOWNWARD_BACKGROUND
		background_sprite.hframes = DOWNWARD_FRAME_COUNT
		background_sprite.flip_h = false

		foreground_sprite.texture = DOWNWARD_FOREGROUND
		foreground_sprite.hframes = DOWNWARD_FRAME_COUNT
		foreground_sprite.visible = true
		foreground_sprite.flip_h = false
		return

	dig_variant = DigVariant.HORIZONTAL
	dig_direction = 1.0 if left_is_source and not right_is_source else -1.0
	frame_count = HORIZONTAL_FRAME_COUNT
	background_sprite.texture = HORIZONTAL_BACKGROUND
	background_sprite.hframes = HORIZONTAL_FRAME_COUNT
	background_sprite.visible = true
	foreground_sprite.texture = HORIZONTAL_FOREGROUND
	foreground_sprite.hframes = HORIZONTAL_FRAME_COUNT
	foreground_sprite.visible = true
	var should_flip := dig_direction > 0.0
	background_sprite.flip_h = should_flip
	foreground_sprite.flip_h = should_flip

static func _is_existing_room(room: RoomBase) -> bool:
	return room != null and room is not RoomDigging

static func _is_existing_basement_room(room: RoomBase) -> bool:
	return _is_existing_room(room) and room.y < 0

static func custom_placement_check(location: Vector2i) -> bool:
	if location.y >= 0:
		return false

	if Building.get_room_from_index(location) != null:
		return false

	var left_room := Building.get_room_from_index(location + Vector2i(-1, 0)) as RoomBase
	var right_room := Building.get_room_from_index(location + Vector2i(1, 0)) as RoomBase
	var room_above := Building.get_room_from_index(location + Vector2i(0, 1)) as RoomBase
	return _is_existing_basement_room(left_room) or _is_existing_basement_room(right_room) or _is_existing_room(room_above)
