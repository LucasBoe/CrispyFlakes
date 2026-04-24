extends RoomOutsideBase
class_name RoomOuthouse

@onready var outhouse_sprite: Sprite2D = $ModulesRoot/Bucket/SmallBucket/Outhouse

const FRAME_DURATION := 0.08
const DEFAULT_MAX_USES := 10
const USE_DURATION := 7.0
const SERVICE_PRICE := 2

var user : NPC
var uses : int = 0
var queue: Array = []

func join_queue(npc: NPC) -> void:
	if not queue.has(npc):
		queue.append(npc)

func leave_queue(npc: NPC) -> void:
	queue.erase(npc)

func is_at_front(npc: NPC) -> bool:
	return queue.size() > 0 and queue[0] == npc

func is_occupied() -> bool:
	return user != null

func get_queue_position(npc: NPC) -> Vector2:
	var index = queue.find(npc)
	if index < 0:
		return get_center_floor_position()
	var direction: float = get_preferred_horizontal_queue_direction(1.0 if global_position.x >= 0 else -1.0)
	return get_center_floor_position() + Vector2(direction * (index + 1) * 14, 0)

func init_room(_x : int, _y : int):
	associated_job = Enum.Jobs.OUTHOUSE_CLEANER
	super.init_room(_x, _y)

func is_used_by_other_then(npc : NPC):
	if user == null:
		return false

	return user != npc

func is_full() -> bool:
	return uses >= get_max_uses()

func get_max_uses() -> int:
	if current_module != null and current_module.max_guests > 0:
		return current_module.max_guests
	return DEFAULT_MAX_USES

func get_service_price() -> int:
	return SERVICE_PRICE

func play_open_animation() -> void:
	var last_frame : int = outhouse_sprite.hframes * outhouse_sprite.vframes - 1
	for f in range(0, last_frame + 1):
		outhouse_sprite.frame = f
		await get_tree().create_timer(FRAME_DURATION).timeout

func play_close_animation() -> void:
	var last_frame : int = outhouse_sprite.hframes * outhouse_sprite.vframes - 1
	for f in range(last_frame - 1, -1, -1):
		outhouse_sprite.frame = f
		await get_tree().create_timer(FRAME_DURATION).timeout
