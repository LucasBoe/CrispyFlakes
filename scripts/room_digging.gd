extends RoomBase
class_name RoomDigging

const FRAME_COUNT := 12

@onready var background_sprite: Sprite2D = $Background
@onready var foreground_sprite: Sprite2D = $Foreground
@onready var progress_bar: TextureProgressBar = $ProgressBar

var dig_direction := -1.0

func init_room(_x: int, _y: int):
	is_outside_room = true
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.DIGGING
	_refresh_dig_direction()
	set_dig_progress(0.0)

func set_dig_progress(progress: float) -> void:
	var frame_index: int = clampi(floori(progress * float(FRAME_COUNT - 1)), 0, FRAME_COUNT - 1)
	background_sprite.frame = frame_index
	foreground_sprite.frame = frame_index
	progress_bar.max_value = 100.0
	progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0
	progress_bar.visible = progress > 0.0 and progress < 1.0

func get_dig_start_position() -> Vector2:
	if dig_direction > 0.0:
		return global_position + Vector2(-12, 0)
	return global_position + Vector2(60, 0)

func get_dig_end_position() -> Vector2:
	if dig_direction > 0.0:
		return global_position + Vector2(32, 0)
	return global_position + Vector2(16, 0)

func _refresh_dig_direction() -> void:
	var left_room := Building.get_room_from_index(Vector2i(x - 1, y)) as RoomBase
	var right_room := Building.get_room_from_index(Vector2i(x + 1, y)) as RoomBase
	var left_is_source := _is_existing_basement_room(left_room)
	var right_is_source := _is_existing_basement_room(right_room)

	dig_direction = 1.0 if left_is_source and not right_is_source else -1.0
	var should_flip := dig_direction > 0.0
	background_sprite.flip_h = should_flip
	foreground_sprite.flip_h = should_flip

static func _is_existing_basement_room(room: RoomBase) -> bool:
	return room != null and room.y < 0 and room is not RoomDigging

static func custom_placement_check(location: Vector2i) -> bool:
	if location.y >= 0:
		return false
	var left_room := Building.get_room_from_index(location + Vector2i(-1, 0)) as RoomBase
	var right_room := Building.get_room_from_index(location + Vector2i(1, 0)) as RoomBase
	return _is_existing_basement_room(left_room) or _is_existing_basement_room(right_room)
