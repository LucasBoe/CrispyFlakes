extends RoomBase
class_name RoomElevator

const QUEUE_SPACING := 10.0

var queue_up: Array[NPC] = []
var queue_down: Array[NPC] = []

func get_cage_stop_position() -> Vector2:
	return get_center_floor_position()

func get_boarding_position() -> Vector2:
	return get_center_floor_position() + Vector2(-12.0, 0.0)

func get_exit_position() -> Vector2:
	return get_center_floor_position() + Vector2(12.0, 0.0)

func join_queue(npc: NPC, direction: int) -> void:
	var queue := _queue_for_direction(direction)
	if not queue.has(npc):
		queue.append(npc)

func leave_queue(npc: NPC, direction: int) -> void:
	_queue_for_direction(direction).erase(npc)

func get_queue_position(npc: NPC, direction: int) -> Vector2:
	var index := _queue_for_direction(direction).find(npc)
	if index < 0:
		return get_center_floor_position()
	return QueueHelper.get_queue_slot_position(self, index, QUEUE_SPACING)

func _queue_for_direction(direction: int) -> Array:
	return queue_up if direction > 0 else queue_down
