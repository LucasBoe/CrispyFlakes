extends RoomBase
class_name RoomMineshaftEntrance

const BACKGROUND_LEFT := preload("res://assets/sprites/mineshaft_entrance_left_background.png")
const BACKGROUND_LEFT_ONLY := preload("res://assets/sprites/mineshaft_entrance_left_only_background.png")
const BACKGROUND_RIGHT := preload("res://assets/sprites/mineshaft_entrance_right_background.png")
const BACKGROUND_RIGHT_ONLY := preload("res://assets/sprites/mineshaft_entrance_right_only_background.png")
const FOREGROUND_LEFT := preload("res://assets/sprites/mineshaft_entrance_left_foreground.png")
const FOREGROUND_LEFT_ONLY := preload("res://assets/sprites/mineshaft_entrance_left_only_foreground.png")
const FOREGROUND_RIGHT := preload("res://assets/sprites/mineshaft_entrance_right_foreground.png")
const FOREGROUND_RIGHT_ONLY := preload("res://assets/sprites/mineshaft_entrance_right_only_foreground.png")

@onready var background_sprite: Sprite2D = $Background
@onready var foreground_sprite: Sprite2D = $Foreground

var _opens_left: bool = true
var _direction_ready: bool = false

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.MINER
	call_deferred("_setup_direction")

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func _setup_direction() -> void:
	if not is_instance_valid(self):
		return

	var left_open: bool = Building.get_room_from_index(Vector2i(x - 1, y)) == null
	var right_open: bool = Building.get_room_from_index(Vector2i(x + 1, y)) == null

	if not left_open and not right_open:
		Building.replace_with_empty(self)
		return

	_opens_left = left_open
	_direction_ready = true
	refresh_entrance_layout()

func refresh_entrance_layout() -> void:
	if not _direction_ready or not is_instance_valid(self):
		return

	var dir := Vector2i.LEFT if _opens_left else Vector2i.RIGHT
	var neighbor: RoomBase = Building.get_room_from_index(Vector2i(x, y) + dir)
	var has_tunnel := neighbor is RoomMineshaft

	if _opens_left:
		background_sprite.texture = BACKGROUND_LEFT if has_tunnel else BACKGROUND_LEFT_ONLY
		foreground_sprite.texture = FOREGROUND_LEFT if has_tunnel else FOREGROUND_LEFT_ONLY
	else:
		background_sprite.texture = BACKGROUND_RIGHT if has_tunnel else BACKGROUND_RIGHT_ONLY
		foreground_sprite.texture = FOREGROUND_RIGHT if has_tunnel else FOREGROUND_RIGHT_ONLY
