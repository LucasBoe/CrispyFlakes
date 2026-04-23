extends RoomBase
class_name RoomToilet

const STALL_COUNT := 2
const USE_DURATION := 5.0
const STALL_POSITIONS := [Vector2(14, 0), Vector2(34, 0)]

var users: Array[NPC] = []
var queue: Array[NPC] = []
var _stall_users: Dictionary = {}

func join_queue(waiting_npc: NPC) -> void:
	if not queue.has(waiting_npc):
		queue.append(waiting_npc)

func leave_queue(waiting_npc: NPC) -> void:
	queue.erase(waiting_npc)

func get_open_stall_count() -> int:
	return STALL_COUNT - users.size()

func can_enter(waiting_npc: NPC) -> bool:
	var queue_index := queue.find(waiting_npc)
	if queue_index < 0:
		return false
	return queue_index < get_open_stall_count() and has_working_water_supply()

func reserve_stall(waiting_npc: NPC) -> bool:
	if users.has(waiting_npc):
		return true
	if users.size() >= STALL_COUNT:
		return false

	var tower := get_available_water_tower()
	if tower == null:
		return false

	tower.consume_water()
	leave_queue(waiting_npc)
	users.append(waiting_npc)
	_stall_users[waiting_npc] = _get_next_open_stall_index()
	return true

func release_stall(leaving_npc: NPC) -> void:
	users.erase(leaving_npc)
	_stall_users.erase(leaving_npc)

func get_queue_position(waiting_npc: NPC) -> Vector2:
	var index := queue.find(waiting_npc)
	if index < 0:
		return get_center_floor_position()
	var direction: float = 1.0 if global_position.x >= 0.0 else -1.0
	return get_center_floor_position() + Vector2(direction * (index + 1) * 10.0, 0.0)

func get_stall_position(using_npc: NPC) -> Vector2:
	var stall_index: int = _stall_users.get(using_npc, 0)
	return global_position + STALL_POSITIONS[stall_index]

func has_water_tower() -> bool:
	return Building.count_rooms_by_data(Building.room_data_water_tower) > 0

func has_working_water_supply() -> bool:
	return get_available_water_tower() != null

func get_available_water_tower() -> RoomWaterTower:
	for tower: RoomWaterTower in Building.query.rooms_of_type_ordered_by_distance(RoomWaterTower, global_position):
		if tower.has_water():
			return tower
	return null

func get_unusable_status_text() -> String:
	return "needs tower" if not has_water_tower() else "no water"

func _get_next_open_stall_index() -> int:
	for i in STALL_COUNT:
		if not _stall_users.values().has(i):
			return i
	return 0
