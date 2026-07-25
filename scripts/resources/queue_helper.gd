extends RefCounted
class_name QueueHelper

const CLAMP_STEP := 4.0

## Queue slot position at `index`, spaced `spacing` apart, clamped back onto the room's floor.
static func get_queue_slot_position(room: RoomBase, index: int, spacing: float) -> Vector2:
	var center: Vector2 = room.get_center_floor_position()
	var direction: float = room.get_preferred_horizontal_queue_direction(1.0 if room.global_position.x >= 0.0 else -1.0)
	var target: Vector2 = center + Vector2(direction * (index + 1) * spacing, 0.0)
	return _get_valid_queue_position(room, target)

static func _get_valid_queue_position(room: RoomBase, queue_target: Vector2) -> Vector2:
	var center: Vector2 = room.get_center_floor_position()
	var clamped_target: Vector2 = queue_target

	while true:
		var found := Building.query.room_at_position(clamped_target) as RoomBase
		if found != null and found.y == room.y and found is not RoomStairs:
			return clamped_target

		if is_equal_approx(clamped_target.x, center.x):
			return center

		clamped_target.x = move_toward(clamped_target.x, center.x, CLAMP_STEP)

	return center
