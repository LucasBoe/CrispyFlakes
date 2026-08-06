extends RoomEntertainment
class_name RoomOpera

const FOREGROUND_TEXTURE_PATH := "res://assets/sprites/room_opera_foreground.png"
const ROOM_CENTER_OFFSET := Vector2(72.0, -48.0)
const TOP_CENTER_OFFSET := Vector2(72.0, -96.0)
const FLOOR_CENTER_OFFSET := Vector2(72.0, 0.0)
const STAGE_CENTER_OFFSET := Vector2(72.0, -16.0)
const NOTIFICATION_OFFSET := Vector2(50.0, -56.0)
const BALCONY_SLOT_LOCAL_POSITIONS := [
	Vector2(18.0, -32.0),
	Vector2(30.0, -32.0),
	Vector2(42.0, -32.0),
	Vector2(102.0, -32.0),
	Vector2(114.0, -32.0),
	Vector2(126.0, -32.0),
	Vector2(18.0, -64.0),
	Vector2(30.0, -64.0),
	Vector2(42.0, -64.0),
	Vector2(102.0, -64.0),
	Vector2(114.0, -64.0),
	Vector2(126.0, -64.0),
]
const GROUND_ROW_SLOT_LOCAL_POSITIONS := [
	Vector2(8.0, 0.0),
	Vector2(16.0, 0.0),
	Vector2(24.0, 0.0),
	Vector2(32.0, 0.0),
	Vector2(40.0, 0.0),
	Vector2(104.0, 0.0),
	Vector2(112.0, 0.0),
	Vector2(120.0, 0.0),
	Vector2(128.0, 0.0),
	Vector2(136.0, 0.0),
]
const GROUND_ROW_SLOT_START_INDEX := 12

static var _foreground_texture: Texture2D

@onready var foreground_sprite: Sprite2D = $Foreground

var _balcony_slot_users: Dictionary = {}

func _ready() -> void:
	if foreground_sprite != null:
		foreground_sprite.texture = _get_foreground_texture()

func init_room(_x: int, _y: int):
	super.init_room(_x, _y)
	associated_job = Enum.Jobs.OPERA_SINGER

func get_random_floor_position():
	return global_position + Vector2(randi_range(8, 136), 0)

func get_center_position():
	return global_position + ROOM_CENTER_OFFSET

func get_top_center_position():
	return global_position + TOP_CENTER_OFFSET

func get_center_floor_position():
	return global_position + FLOOR_CENTER_OFFSET
	
func get_center_stage_position():
	return global_position + STAGE_CENTER_OFFSET

func get_balcony_slot_count() -> int:
	return BALCONY_SLOT_LOCAL_POSITIONS.size() + GROUND_ROW_SLOT_LOCAL_POSITIONS.size()

func get_occupied_balcony_slot_count() -> int:
	var occupied := 0
	for guest in _balcony_slot_users.values():
		if is_instance_valid(guest):
			occupied += 1
	return occupied

func can_accept_guest() -> bool:
	return get_occupied_balcony_slot_count() < get_balcony_slot_count()

func reserve_balcony_slot(guest: NPCGuest) -> int:
	if guest == null:
		return -1

	for i in range(get_balcony_slot_count()):
		if _balcony_slot_users.get(i, null) == guest:
			return i

	for i in range(get_balcony_slot_count()):
		var occupant := _balcony_slot_users.get(i, null) as NPCGuest
		if occupant == null or not is_instance_valid(occupant):
			_balcony_slot_users[i] = guest
			return i

	return -1

func has_guest_in_balcony_slot(guest: NPCGuest, slot_index: int) -> bool:
	if guest == null or slot_index < 0 or slot_index >= get_balcony_slot_count():
		return false
	return _balcony_slot_users.get(slot_index, null) == guest

func release_balcony_slot(guest: NPCGuest) -> void:
	if guest == null:
		return

	for i in _balcony_slot_users.keys():
		if _balcony_slot_users[i] == guest:
			_balcony_slot_users.erase(i)
			return

func get_balcony_slot_world_position(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= get_balcony_slot_count():
		return get_center_floor_position()
	return global_position + _get_guest_slot_local_position(slot_index)

func get_balcony_slot_facing_direction(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= get_balcony_slot_count():
		return -1.0

	var local_pos: Vector2 = _get_guest_slot_local_position(slot_index)
	return -1.0 if local_pos.x >= ROOM_CENTER_OFFSET.x else 1.0

func _get_guest_slot_local_position(slot_index: int) -> Vector2:
	if slot_index < BALCONY_SLOT_LOCAL_POSITIONS.size():
		return BALCONY_SLOT_LOCAL_POSITIONS[slot_index]
	var ground_index := slot_index - GROUND_ROW_SLOT_START_INDEX
	return GROUND_ROW_SLOT_LOCAL_POSITIONS[ground_index]

func get_notification_position():
	return global_position + NOTIFICATION_OFFSET

func get_performance_name() -> String:
	return "Opera Singer"

func has_active_performance() -> bool:
	return worker != null

func entertain_guests() -> int:
	if Global.NPCSpawner == null:
		return 0

	var mood_effect := get_mood_boost()
	var reason := "Opera"
	if worker != null and worker.Traits != null:
		mood_effect = worker.Traits.get_opera_mood_effect(mood_effect)
		reason = worker.Traits.get_opera_mood_reason()

	var affected_guest_count := 0
	for guest: NPCGuest in Global.NPCSpawner.get_live_guests():
		guest.add_mood(mood_effect, reason)
		affected_guest_count += 1

	return affected_guest_count

func _is_guest_in_range(guest: NPCGuest) -> bool:
	if not is_instance_valid(guest):
		return false

	var guest_room_index: Vector2i = Building.round_room_index_from_global_position(guest.global_position)
	var center_x: int = x + 1
	return guest_room_index.y == y and absi(guest_room_index.x - center_x) <= PERFORMANCE_RANGE

func _get_foreground_texture() -> Texture2D:
	if _foreground_texture != null:
		return _foreground_texture

	var image := Image.load_from_file(ProjectSettings.globalize_path(FOREGROUND_TEXTURE_PATH))
	_foreground_texture = ImageTexture.create_from_image(image) if image != null and not image.is_empty() else null
	return _foreground_texture
