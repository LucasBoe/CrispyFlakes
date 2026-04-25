extends Node2D
class_name NavigationModule

var _debug = true

var npc: NPC
var current_room_index
var target_path = []
var target_final

var has_target = false
var is_moving = false
var _stair_waypoints_remaining: int = 0
var _is_inside: bool = false
var _last_known_room: RoomBase = null
var _has_enter_gate: bool = false
var _enter_gate_position: Vector2 = Vector2.ZERO
var _has_leave_gate: bool = false
var _leave_gate_position: Vector2 = Vector2.ZERO

const DEFAULT_MOVE_SPEED = 32
var move_speed = DEFAULT_MOVE_SPEED

signal target_reached_signal

func _ready():
	npc = get_parent() as NPC
	npc.Navigation = self

func _process(delta):
	if not has_target:
		return

	npc.Animator.direction = Vector2.ZERO

	if global_position.distance_to(target_path[0]) < 1:
		npc.global_position = target_path[0]
		_on_waypoint_arrived(target_path[0])
		target_path.remove_at(0)
		if _stair_waypoints_remaining > 0:
			_stair_waypoints_remaining -= 1
		if target_path.is_empty():
			stop_navigation()
			target_reached_signal.emit()
			return

	npc.Animator.direction = target_path[0] - npc.global_position
	npc.global_position = npc.global_position.move_toward(target_path[0], delta * move_speed)
	_check_inside_outside_transition()


func stop_navigation():
	target_final = null
	has_target = false
	is_moving = false
	_stair_waypoints_remaining = 0
	npc.Animator.direction = Vector2.ZERO
	if _has_enter_gate:
		_has_enter_gate = false
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	_has_leave_gate = false
	_check_inside_outside_transition()

func is_on_stair_path() -> bool:
	return _stair_waypoints_remaining > 0


func set_target(target, custom_speed):
	if target is Vector2 or is_instance_valid(target):
		target_final = target
		refresh_target_path()
		is_moving = true
		has_target = true
		var base_speed = DEFAULT_MOVE_SPEED * (0.75 + npc.agility * 0.5) if custom_speed < 0 else custom_speed
		move_speed = base_speed * npc.Traits.get_move_speed_multiplier()

func get_random_target():
	var rooms: Array = []
	for floor_rooms in Building.floors.values():
		for room: RoomBase in floor_rooms.values():
			if not room.is_outside_room:
				rooms.append(room)
	return rooms.pick_random()


func refresh_room_index():
	current_room_index = Building.round_floor_index_from_global_position(global_position)


func get_reachable_rooms() -> Array[RoomBase]:
	var start_room := _get_current_floor_room(global_position)
	if start_room == null:
		return []

	var reachable: Array[RoomBase] = []
	var open: Array[RoomBase] = [start_room]
	var visited := {}
	visited[start_room] = true

	while open.size() > 0:
		var current = open.pop_front()
		reachable.append(current)
		for neighbor in _get_connected_rooms(current):
			if neighbor != null and not visited.has(neighbor):
				visited[neighbor] = true
				open.push_back(neighbor)

	return reachable


func is_room_reachable(room: RoomBase) -> bool:
	var start_room := _get_current_floor_room(global_position)

	if start_room == null or room == null:
		return false

	var path := _find_room_path(start_room, room)
	return path.size() > 0


func get_connected_rooms(room: RoomBase) -> Array[RoomBase]:
	return _get_connected_rooms(room)


func check_valid_path(start_pos: Vector2, goal_pos: Vector2) -> bool:
	var start_room := _get_current_floor_room(start_pos)
	var goal_room := _get_goal_floor_room(goal_pos)

	if start_room == null or goal_room == null:
		if _debug:
			_draw_debug_line(start_pos, goal_pos, false)
		return false

	var path := _find_room_path(start_room, goal_room)
	var valid := path.size() > 0

	if _debug:
		_draw_room_path(path, valid, start_pos, goal_pos)

	return valid


func refresh_target_path() -> void:
	target_path.clear()
	_stair_waypoints_remaining = 0
	_has_enter_gate = false
	_has_leave_gate = false

	var final_target: Vector2
	#if target_final is NPC:
		# Navigate to the room the target NPC is currently in rather than their
		# exact position — room centers are stable, so path refreshes mid-stair
		# don't cause oscillation.
		#var target_room := Building.query.closest_room_of_type(RoomBase, (target_final as NPC).global_position) as RoomBase
		#final_target = target_room.get_center_floor_position() if target_room != null else (target_final as NPC).global_position
	if target_final is RoomBase:
		final_target = (target_final as RoomBase).get_center_floor_position()
	elif target_final is Node2D:
		final_target = (target_final as Node2D).global_position
	else:
		final_target = target_final

	refresh_room_index()

	var start_room := _get_current_floor_room(global_position)
	var goal_room := _get_goal_floor_room(final_target)

	if start_room == null or goal_room == null:
		_fail_target_path()
		return

	if not (npc is NPCWorker) and not _should_ignore_bouncer_gate() and not _is_inside and not _is_outside_target(final_target):
		var bouncer_room: RoomBouncer = Building.query.closest_room_of_type(RoomBouncer, global_position) as RoomBouncer
		if bouncer_room != null:
			var path_from_bouncer: Array[RoomBase] = _find_room_path(bouncer_room, goal_room)
			if not path_from_bouncer.is_empty():
				target_path.append(bouncer_room.get_center_floor_position())
				for i in range(path_from_bouncer.size() - 1):
					_append_transition_to_target_path(path_from_bouncer[i], path_from_bouncer[i + 1], i == path_from_bouncer.size() - 2)
				target_path.append(final_target)
				_has_enter_gate = true
				_enter_gate_position = bouncer_room.get_center_floor_position()
				return

	if not (npc is NPCWorker) and not _should_ignore_bouncer_gate() and _is_inside and _is_outside_target(final_target):
		var bouncer_room: RoomBouncer = Building.query.closest_room_of_type(RoomBouncer, global_position) as RoomBouncer
		if bouncer_room != null:
			var path_to_bouncer: Array[RoomBase] = _find_room_path(start_room, bouncer_room)
			if not path_to_bouncer.is_empty():
				for i in range(path_to_bouncer.size() - 1):
					_append_transition_to_target_path(path_to_bouncer[i], path_to_bouncer[i + 1], i == path_to_bouncer.size() - 2)
				target_path.append(bouncer_room.get_center_floor_position())
				target_path.append(final_target)
				_has_leave_gate = true
				_leave_gate_position = bouncer_room.get_center_floor_position()
				return

	var room_path := _find_room_path(start_room, goal_room)
	if room_path.is_empty():
		UiNotifications.create_notification_dynamic("?", npc, Vector2(0, -32), Building.room_data_stairs.room_icon)
		_fail_target_path()
		return

	for i in range(room_path.size() - 1):
		var from_room := room_path[i] as RoomBase
		var to_room := room_path[i + 1] as RoomBase
		_append_transition_to_target_path(from_room, to_room, i == room_path.size() - 2)

	target_path.append(final_target)


func _find_room_path(start_room: RoomBase, goal_room: RoomBase) -> Array[RoomBase]:
	if start_room == goal_room:
		return [start_room]

	var open: Array[RoomBase] = [start_room]
	var visited := {}
	var came_from := {}

	visited[start_room] = true

	while open.size() > 0:
		var current = open.pop_front()

		if current == goal_room:
			return _reconstruct_path(came_from, goal_room)

		for neighbor in _get_connected_rooms(current):
			if neighbor == null or visited.has(neighbor):
				continue
			visited[neighbor] = true
			came_from[neighbor] = current
			open.push_back(neighbor)

	return []


func _get_connected_rooms(room: RoomBase) -> Array[RoomBase]:
	var result: Array[RoomBase] = []

	if not is_instance_valid(room):
		return result

	# 1. Ground floor rooms are all mutually reachable
	if room.y == 0:
		var all_rooms = Building.query.all_rooms_of_type(RoomBase)
		for other in all_rooms:
			if is_instance_valid(other) and other != room and other.y == 0:
				result.append(other)

	# 2. Horizontal adjacency — skip over the room's own footprint
	var w = room.data.width if room.data != null else 1
	var left_room = Building.get_room_from_index(Vector2i(room.x - 1, room.y))
	var right_room = Building.get_room_from_index(Vector2i(room.x + w, room.y))
	if left_room is RoomBase:
		result.append(left_room)
	if right_room is RoomBase:
		result.append(right_room)

	# 3. Vertical movement via stairs on the lower floor
	if room is RoomStairs:
		var room_above := _get_room_above_stairs(room as RoomStairs)
		if room_above != null:
			result.append(room_above)

	for stair_below in _get_stairs_below(room):
		if stair_below != room:
			result.append(stair_below)

	return result


func _append_transition_to_target_path(from_room: RoomBase, to_room: RoomBase, is_final := false) -> void:
	if from_room == null or to_room == null:
		return

	# Vertical movement uses the stair on the lower floor.
	var transition_stairs := _get_transition_stairs(from_room, to_room)
	if transition_stairs != null and from_room.y != to_room.y:
		if _debug:
			print(
				"[STAIRS][PATH] ",
				npc.name,
				" from=",
				_debug_room_label(from_room),
				" to=",
				_debug_room_label(to_room),
				" using=",
				_debug_room_label(transition_stairs),
				" dir=",
				"down" if to_room.y < from_room.y else "up",
				" room_above=",
				_debug_room_label(_get_room_above_stairs(transition_stairs))
			)
		_append_stairs_transition(transition_stairs, to_room.y < from_room.y)
		if not is_final and to_room is not RoomStairs:
			target_path.append(to_room.get_center_floor_position())
		return

	# Skip center waypoint when entering stairs (zig-zag provides the entry point)
	# or on the last hop (final_target handles the destination)
	if to_room is RoomStairs or is_final:
		return

	target_path.append(to_room.get_center_floor_position())


func _append_stairs_transition(stairs: RoomStairs, go_downwards: bool) -> void:
	if stairs == null:
		return

	if _debug:
		print(
			"[STAIRS][TRANSITION] ",
			npc.name,
			" stairs=",
			_debug_room_label(stairs),
				" go_down=",
				go_downwards,
				" ",
				_debug_stair_geometry(stairs)
		)

	_append_stairs_zig_zag(stairs, go_downwards)


func _append_stairs_zig_zag(stairs: RoomStairs, go_downwards: bool) -> void:
	_stair_waypoints_remaining += 4
	var waypoints: Array[Vector2] = []
	var room_above := _get_room_above_stairs(stairs)
	var top_aligned_origin := stairs.global_position + Vector2(0, -48)
	if go_downwards:
		waypoints = [
			top_aligned_origin + Vector2(8, 0),
			top_aligned_origin + Vector2(28, 24),
			top_aligned_origin + Vector2(36, 24),
			top_aligned_origin + Vector2(36, 48),
		]
	else:
		waypoints = [
			top_aligned_origin + Vector2(36, 48),
			top_aligned_origin + Vector2(36, 24),
			top_aligned_origin + Vector2(28, 24),
			top_aligned_origin + Vector2(8, 0),
		]

	if _debug:
		for i in range(waypoints.size()):
			print(
				"[STAIRS][WAYPOINT] ",
				npc.name,
				" step=",
				i,
				" anchor=",
				_debug_room_label(stairs),
				" above=",
				_debug_room_label(room_above),
				" delta=",
				waypoints[i] - stairs.global_position,
				" waypoint=",
				_debug_waypoint_label(waypoints[i])
			)

	for waypoint in waypoints:
		target_path.append(waypoint)


func _fail_target_path() -> void:
	target_path.clear()
	var current_room := _get_current_floor_room(global_position)
	if current_room != null:
		target_path.append(current_room.get_random_floor_position())


func _reconstruct_path(came_from: Dictionary, goal_room: RoomBase) -> Array[RoomBase]:
	var path: Array[RoomBase] = [goal_room]
	var current = goal_room
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path


func _draw_room_path(path: Array[RoomBase], valid: bool, start_pos: Vector2, goal_pos: Vector2) -> void:
	var color := Color.GREEN if valid else Color.RED
	if path.size() < 2:
		DebugDraw2D.line(start_pos, goal_pos, color)
		return
	for i in range(path.size() - 1):
		DebugDraw2D.line(path[i].get_center_position(), path[i + 1].get_center_position(), color)


func _on_waypoint_arrived(pos: Vector2) -> void:
	if _has_enter_gate and pos.distance_to(_enter_gate_position) < 2.0:
		_has_enter_gate = false
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
		_try_frisk_at_bouncer()
	if _has_leave_gate and pos.distance_to(_leave_gate_position) < 2.0:
		_has_leave_gate = false
		npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)


func _try_frisk_at_bouncer() -> void:
	if not npc is NPCGuest:
		return
	var bouncer_room: RoomBouncer = Building.query.closest_room_of_type(RoomBouncer, global_position) as RoomBouncer
	if bouncer_room == null or not bouncer_room.has_active_bouncer():
		return
	var bounty = BountyHandler.get_official_bounty_for(npc)
	if bounty == null:
		return
	var best_intelligence := 0.0
	for bouncer in bouncer_room.assigned_bouncers:
		if is_instance_valid(bouncer):
			var effective_intelligence = bouncer.intelligence * bouncer.Traits.get_criminal_detection_multiplier()
			best_intelligence = maxf(best_intelligence, effective_intelligence)
	if best_intelligence == 0.0:
		return
	if randf() < minf(1.0, best_intelligence):
		(npc as NPCGuest).is_known_fugitive = true

func _should_ignore_bouncer_gate() -> bool:
	return target_final is NPC

func _is_outside_target(pos: Vector2) -> bool:
	var room := Building.query.room_at_floor_position(pos) as RoomBase
	return room == null or room.is_outside_room


func _check_inside_outside_transition() -> void:
	var current_room := Building.query.room_at_floor_position(global_position) as RoomBase
	if current_room == _last_known_room:
		return
	var prev_room: RoomBase = _last_known_room
	_last_known_room = current_room
	var entering: bool = (prev_room == null or prev_room.is_outside_room) and (current_room != null and not current_room.is_outside_room)
	var leaving: bool = (prev_room != null and not prev_room.is_outside_room) and (current_room == null or current_room.is_outside_room)
	if entering:
		_is_inside = true
		if not _has_enter_gate:
			npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	elif leaving:
		_is_inside = false
		npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)

func _get_current_floor_room(pos: Vector2) -> RoomBase:
	return Building.query.closest_on_current_floor(RoomBase, pos) as RoomBase

func _get_goal_floor_room(pos: Vector2) -> RoomBase:
	return Building.query.closest_on_position_floor(RoomBase, pos) as RoomBase


func _get_room_above_stairs(stairs: RoomStairs) -> RoomBase:
	if stairs == null:
		return null
	return Building.get_room_from_index(Vector2i(stairs.x, stairs.y + 1)) as RoomBase


func _get_stairs_below(room: RoomBase) -> Array[RoomStairs]:
	var stairs_below: Array[RoomStairs] = []
	if room == null:
		return stairs_below

	var width := room.data.width if room.data != null else 1
	for offset in range(width):
		var stair := Building.get_room_from_index(Vector2i(room.x + offset, room.y - 1)) as RoomStairs
		if stair != null and stair not in stairs_below:
			stairs_below.append(stair)

	return stairs_below


func _get_transition_stairs(from_room: RoomBase, to_room: RoomBase) -> RoomStairs:
	if from_room is RoomStairs and _get_room_above_stairs(from_room as RoomStairs) == to_room:
		return from_room as RoomStairs

	if to_room is RoomStairs and _get_room_above_stairs(to_room as RoomStairs) == from_room:
		return to_room as RoomStairs

	return null


func _debug_room_label(room: RoomBase) -> String:
	if room == null:
		return "null"

	var room_name := room.data.room_name if room.data != null else room.get_class()
	return "%s[%d,%d]@%s" % [room_name, room.x, room.y, str(room.global_position)]


func _debug_stair_geometry(stairs: RoomStairs) -> String:
	if stairs == null:
		return "stairs=null"

	var room_above := _get_room_above_stairs(stairs)
	var sprite_center: Variant = stairs.stairs_sprite.global_position if stairs.stairs_sprite != null else "null"
	return "origin=%s floor_center=%s top_center=%s sprite_center=%s floor_room=%s visual_room=%s above=%s above_floor_center=%s" % [
		str(stairs.global_position),
		str(stairs.get_center_floor_position()),
		str(stairs.get_top_center_position()),
		str(sprite_center),
		_debug_room_label(Building.query.room_at_floor_position(stairs.global_position) as RoomBase),
		_debug_room_label(Building.query.room_at_position(stairs.global_position) as RoomBase),
		_debug_room_label(room_above),
		str(room_above.get_center_floor_position() if room_above != null else null),
	]


func _debug_waypoint_label(pos: Vector2) -> String:
	var biased_pos: Vector2 = pos + Vector2(0, Building.FLOOR_POSITION_Y_BIAS)
	var floor_idx: Vector2i = Building.round_floor_index_from_global_position(pos)
	return "%s biased=%s room_idx=%s floor_idx=%s floor_origin=%s floor=%s visual=%s" % [
		str(pos),
		str(biased_pos),
		str(Building.round_room_index_from_global_position(pos)),
		str(floor_idx),
		str(Building.global_position_from_room_index(floor_idx)),
		_debug_room_label(Building.query.room_at_floor_position(pos) as RoomBase),
		_debug_room_label(Building.query.room_at_position(pos) as RoomBase),
	]


func _draw_debug_line(start_pos: Vector2, goal_pos: Vector2, valid: bool) -> void:
	DebugDraw2D.line(start_pos, goal_pos, Color.GREEN if valid else Color.RED)
