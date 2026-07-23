extends Node2D
class_name NavigationModule

var _debug = false
var _debug_inside_notification: UiNotifications.instance_info = null

# Shared across all NPCs - toggled via the "debug_zlayer" console command
# (see building.gd). Marks every place _is_inside actually flips with a
# colored marker (lime = swapped indoor, orange = swapped outside) plus a
# console line naming the NPC, the phase kind that caused it, and position -
# for tracking down exactly when/where a swap fires wrongly.
static var debug_zlayer_swaps := false

const ELEVATOR_ROOM_SCRIPT = preload("res://scripts/room_elevator.gd")
const FRISK_PROGRESS_BAR_SCENE = preload("res://scenes/npc_progress_bar.tscn")
const FRISK_DURATION := 1.0

var npc: NPC
var current_room_index
var target_path : Array[navigationPhase] = []
var target_final

var has_target = false
var is_moving = false
var _stair_waypoints_remaining: int = 0
var _active_elevator_request = null
var _frisk_in_progress := false
var _is_inside: bool = false

const DEFAULT_MOVE_SPEED = 32
var move_speed = DEFAULT_MOVE_SPEED

const no_path_icon = preload("uid://byc8yljqbcmo4")

signal target_reached_signal

func _ready():
	npc = get_parent() as NPC
	npc.Navigation = self
	call_deferred("sync_inside_outside_state")

func _process(delta):
	if debug_zlayer_swaps:
		_debug_draw_zlayer_rect()

	if not has_target:
		return

	#this should only be null if the npc is acutally ON an elevator
	if _active_elevator_request != null or _frisk_in_progress:
		npc.Animator.direction = Vector2.ZERO
		return

	if target_path.is_empty():
		stop_navigation()
		target_reached_signal.emit()
		return

	npc.Animator.direction = Vector2.ZERO

	var phase : navigationPhase = target_path[0]

	if phase is useElevatorPhase:
		_start_elevator_phase(phase as useElevatorPhase)
		return

	var target : Vector2 = (phase as useStairsPhase).current_waypoint() if phase is useStairsPhase else phase.target_location

	if global_position.distance_to(target) < 1:
		npc.global_position = target
		if phase is useStairsPhase:
			var stairs_phase := phase as useStairsPhase
			stairs_phase.current_index += 1
			_stair_waypoints_remaining = stairs_phase.waypoints.size() - stairs_phase.current_index
			if not stairs_phase.is_done():
				return
		elif phase is useDoorSwapPhase:
			var door_phase := phase as useDoorSwapPhase
			if door_phase.entering and npc is NPCGuest and is_instance_valid(door_phase.door_room) and door_phase.door_room.has_active_bouncer():
				_start_frisk(door_phase)
				return
			_apply_door_swap_phase(door_phase)
		elif phase is swapInOutSidewaysPhase:
			_apply_sideways_swap_phase(phase as swapInOutSidewaysPhase)
		target_path.remove_at(0)
		if target_path.is_empty():
			stop_navigation()
			target_reached_signal.emit()
			return
		return

	npc.Animator.direction = target - npc.global_position
	npc.global_position = npc.global_position.move_toward(target, delta * move_speed)

	if _debug:
		_draw_debug_path()


func stop_navigation():
	target_final = null
	has_target = false
	is_moving = false
	_stair_waypoints_remaining = 0
	_active_elevator_request = null
	# a stopped navigation has nothing left to resume - if the NPC's position
	# gets changed out from under it before the next set_target (e.g. dragged
	# and dropped elsewhere), a stale in-progress phase must not survive to be
	# wrongly "resumed" by refresh_target_path
	target_path.clear()
	npc.Animator.direction = Vector2.ZERO
	_check_inside_outside_transition()

func is_on_stair_path() -> bool:
	return _stair_waypoints_remaining > 0


func set_target(target, custom_speed):
	if target is Vector2 or is_instance_valid(target):
		target_final = target
		refresh_target_path()
		is_moving = true
		has_target = true
		var base_speed = DEFAULT_MOVE_SPEED if custom_speed < 0 else custom_speed
		move_speed = base_speed * npc.get_move_speed_multiplier()

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
	if _active_elevator_request != null or _frisk_in_progress:
		return

	# a mid-stair NPC must finish the current stair segment before following
	# any newly computed path - pass it along so the new path can resume from
	# its exit instead of restarting from the in-between y the NPC occupies
	var current_phase : navigationPhase = target_path[0] if not target_path.is_empty() else null

	target_path.clear()
	_stair_waypoints_remaining = 0

	#final target compuation
	var final_target: Vector2
	if target_final is NPC:
		var target_room := Building.query.closest_room_of_type(RoomBase, (target_final as NPC).global_position) as RoomBase
		final_target = target_room.get_center_floor_position() if target_room != null else (target_final as NPC).global_position
	elif target_final is RoomBase:
		var target_room := target_final as RoomBase
		refresh_room_index()
		final_target = _get_room_center_floor_position(target_room, target_room.y)
	elif target_final is Node2D:
		final_target = (target_final as Node2D).global_position
	else:
		final_target = target_final

	refresh_room_index()

	# snap to the goal room's exact floor line, so a target sourced from a raw
	# position (Node2D/Vector2) doesn't leave the NPC standing slightly off-grid
	final_target.y = snappedf(final_target.y, 48.0)
	var goal_room := _get_goal_floor_room(final_target)
	if goal_room != null:
		final_target.y = _get_room_floor_y_world(goal_room, goal_room.y)

	# workers aren't gated by the bouncer, and neither is anyone currently
	# chasing another NPC (e.g. an escort/arrest chain shouldn't detour
	# through a supervised door) - both can cross at the open side instead
	var requires_bouncer := not (npc is NPCWorker) and not (target_final is NPC)
	var new_path : Array[navigationPhase] = Building.navigation_helper_query.refresh_target_path(current_phase, global_position, final_target, requires_bouncer)
	if new_path.is_empty():
		UiNotifications.create_notification_dynamic("?", npc, Vector2(0, -32), no_path_icon)
		_fail_target_path()
		return

	target_path = new_path
	if target_path[0] is useStairsPhase:
		var stairs_phase := target_path[0] as useStairsPhase
		_stair_waypoints_remaining = stairs_phase.waypoints.size() - stairs_phase.current_index


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
	var room_width = room.data.width if room.data != null else 1
	if room.y == 0:
		var all_rooms = Building.query.all_rooms_of_type(RoomBase)
		for other in all_rooms:
			if is_instance_valid(other) and other != room and _is_walkable_room_on_floor(other, 0):
				_append_connected_room(result, other, 0)

	# 2. Horizontal adjacency — skip over the room's own footprint
	var left_room = Building.get_room_from_index(Vector2i(room.x - 1, room.y))
	var right_room = Building.get_room_from_index(Vector2i(room.x + room_width, room.y))
	_append_connected_room(result, left_room, room.y)
	_append_connected_room(result, right_room, room.y)

	# 3. Vertical movement via stairs on the lower floor
	if room is RoomStairs:
		var room_above := _get_room_above_stairs(room as RoomStairs)
		_append_connected_room(result, room_above, room.y + 1)

	if room.get_script() == ELEVATOR_ROOM_SCRIPT:
		var elevator_above = Building.get_room_from_index(Vector2i(room.x, room.y + 1))
		var elevator_below = Building.get_room_from_index(Vector2i(room.x, room.y - 1))
		if elevator_above != null and elevator_above.get_script() == ELEVATOR_ROOM_SCRIPT:
			_append_connected_room(result, elevator_above, room.y + 1)
		if elevator_below != null and elevator_below.get_script() == ELEVATOR_ROOM_SCRIPT:
			_append_connected_room(result, elevator_below, room.y - 1)

	for stair_below in _get_stairs_below(room):
		if stair_below != room:
			_append_connected_room(result, stair_below, stair_below.y)

	return result


static func compute_stairs_waypoints(stairs_global_position: Vector2, go_downwards: bool) -> Array[Vector2]:
	var top_aligned_origin := stairs_global_position + Vector2(0, -48)
	if go_downwards:
		return [
			top_aligned_origin + Vector2(8, 0),
			top_aligned_origin + Vector2(28, 24),
			top_aligned_origin + Vector2(36, 24),
			top_aligned_origin + Vector2(36, 48),
		]
	return [
		top_aligned_origin + Vector2(36, 48),
		top_aligned_origin + Vector2(36, 24),
		top_aligned_origin + Vector2(28, 24),
		top_aligned_origin + Vector2(8, 0),
	]

func _fail_target_path() -> void:
	target_path.clear()
	var current_room := _get_current_floor_room(global_position)
	if current_room != null:
		var floor_y: int = Building.round_floor_index_from_global_position(global_position).y
		target_path.append(walkPhase.new(_get_room_random_floor_position(current_room, floor_y)))


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


# Leaving (or entering with no active bouncer to frisk at) is instant, same
# as before. Entering through an active bouncer instead goes through
# _start_frisk, which queues, waits its turn, and removes the phase itself.
func _apply_door_swap_phase(phase: useDoorSwapPhase) -> void:
	if phase.entering:
		_is_inside = true
		npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	else:
		_is_inside = false
		npc.Animator.set_z(Enum.ZLayer.NPC_OUTSIDE)
	_debug_mark_zlayer_swap("door")

# Open-side crossing (no bouncer door involved) - same deterministic,
# phase-driven swap as _apply_door_swap_phase, just for the sideways case.
func _apply_sideways_swap_phase(phase: swapInOutSidewaysPhase) -> void:
	_is_inside = phase.entering
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT if phase.entering else Enum.ZLayer.NPC_OUTSIDE)
	_debug_mark_zlayer_swap("sideways")

func _debug_mark_zlayer_swap(label: String) -> void:
	if not debug_zlayer_swaps or not is_instance_valid(npc):
		return
	print("[zlayer] %s -> %s via %s at %s" % [npc.name, "INSIDE" if _is_inside else "OUTSIDE", label, global_position])

# Always-on overlay (while debug_zlayer_swaps is toggled) so you can see the
# NPC's actual currently-applied z-layer at a glance, not just what
# NavigationModule's own _is_inside thinks - several behaviours (need_pee,
# job_bar, need_sleep, etc.) set Animator.z_index directly, bypassing
# NavigationModule entirely, so reading z_index here (not _is_inside) is the
# only way this reflects ground truth. Redrawn every frame (duration 0.0),
# sized to the NPC's own height so it reads as "which layer is this body on".
func _debug_draw_zlayer_rect() -> void:
	var color := _debug_color_for_zlayer(npc.Animator.z_index)
	DebugDraw2D.rect(global_position + Vector2(0, -12), Vector2(14, 24), color, 2.0)

func _debug_color_for_zlayer(z: int) -> Color:
	match z:
		Enum.ZLayer.NPC_IN_OUTHOUSE:
			return Color.PURPLE
		Enum.ZLayer.NPC_OUTSIDE:
			return Color.ORANGE_RED
		Enum.ZLayer.NPC_FAR_BACK:
			return Color.SADDLE_BROWN
		Enum.ZLayer.NPC_BEHIND_CONTENT:
			return Color.YELLOW
		Enum.ZLayer.NPC_DEFAULT:
			return Color.LIME_GREEN
		Enum.ZLayer.NPC_DRAGGED:
			return Color.MAGENTA
		_:
			return Color.WHITE

# Only one guest gets frisked at a bouncer at a time (see
# RoomBouncer.register_guest_for_frisk) - queue up, wait for a turn, show a
# progress bar for the duration, then resolve the check. Bails out cleanly
# (no phase removal/signal) if navigation gets cancelled or the npc/room
# stops being valid partway through, since this spans many frames.
func _start_frisk(phase: useDoorSwapPhase) -> void:
	_frisk_in_progress = true
	var bouncer_room := phase.door_room
	bouncer_room.register_guest_for_frisk(npc as NPCGuest)

	while is_instance_valid(bouncer_room) and bouncer_room.frisk_current_user != npc:
		await get_tree().process_frame
		if not has_target or not is_instance_valid(npc):
			if is_instance_valid(bouncer_room):
				bouncer_room.unregister_guest_for_frisk(npc as NPCGuest)
			_frisk_in_progress = false
			return

	if is_instance_valid(bouncer_room) and has_target:
		var bar := FRISK_PROGRESS_BAR_SCENE.instantiate() as TextureProgressBar
		npc.add_child(bar)
		var t := 0.0
		while t < FRISK_DURATION:
			t += get_process_delta_time()
			bar.value = clampf((t / FRISK_DURATION) * 100.0, 0.0, 100.0)
			await get_tree().process_frame
			if not has_target or not is_instance_valid(npc):
				bar.queue_free()
				if is_instance_valid(bouncer_room):
					bouncer_room.unregister_guest_for_frisk(npc as NPCGuest)
				_frisk_in_progress = false
				return
		bar.queue_free()

		if is_instance_valid(bouncer_room):
			if has_target:
				_resolve_frisk_check(bouncer_room)
			bouncer_room.unregister_guest_for_frisk(npc as NPCGuest)

	_frisk_in_progress = false

	if not has_target or target_path.is_empty() or target_path[0] != phase:
		return
	_is_inside = true
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	_debug_mark_zlayer_swap("frisk")
	target_path.remove_at(0)
	if target_path.is_empty():
		stop_navigation()
		target_reached_signal.emit()

func _resolve_frisk_check(bouncer_room: RoomBouncer) -> void:
	var bounty = BountyHandler.get_official_bounty_for(npc)
	if bounty == null:
		return
	var best_intelligence := 0.0
	for bouncer in bouncer_room.assigned_bouncers:
		if is_instance_valid(bouncer):
			var effective_intelligence = bouncer.Traits.get_criminal_detection_multiplier()
			best_intelligence = maxf(best_intelligence, effective_intelligence)
	if best_intelligence == 0.0:
		return
	if randf() < minf(1.0, best_intelligence):
		(npc as NPCGuest).is_known_fugitive = true

func sync_inside_outside_state() -> void:
	_check_inside_outside_transition()

func is_heading_outside() -> bool:
	if not _is_inside:
		return true
	if target_final is Vector2:
		return _is_outside_target(target_final)
	if target_final is Node2D:
		return _is_outside_target((target_final as Node2D).global_position)
	return false

func _is_outside_target(pos: Vector2) -> bool:
	var room := Building.query.room_at_floor_position(pos) as RoomBase
	return room == null or room.is_outside_room


# One-off resync to the NPC's actual current room. Used only where phase-
# driven state can't be trusted yet: at spawn (before any phases exist) and
# when navigation is stopped/interrupted (e.g. dragged elsewhere). During
# normal navigation, z-layer/_is_inside are instead set deterministically on
# arrival by _apply_door_swap_phase/_start_frisk/_apply_sideways_swap_phase -
# polling literal room occupancy every frame can't tell "genuinely crossing"
# apart from "just walking past a building on the street".
func _check_inside_outside_transition() -> void:
	var current_room := Building.query.room_at_floor_position(global_position) as RoomBase
	var was_inside := _is_inside
	_is_inside = current_room != null and not current_room.is_outside_room
	if _is_inside != was_inside:
		_debug_mark_zlayer_swap("resync")
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT if _is_inside else Enum.ZLayer.NPC_OUTSIDE)

func _get_current_floor_room(pos: Vector2) -> RoomBase:
	return _get_walkable_room_on_position_floor(pos)

func _get_goal_floor_room(pos: Vector2) -> RoomBase:
	return _get_walkable_room_on_position_floor(pos)


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


func _start_elevator_phase(phase: useElevatorPhase) -> void:
	ElevatorHandler.debug_log("nav start elevator npc=%s from=(%d,%d) to=(%d,%d)" % [
		npc.name,
		phase.from_room.x, phase.from_room.y,
		phase.to_room.x, phase.to_room.y,
	])
	_active_elevator_request = ElevatorHandler.request_trip(npc, phase.from_room, phase.to_room)
	_active_elevator_request.finished.connect(_on_elevator_step_finished, CONNECT_ONE_SHOT)

func _on_elevator_step_finished() -> void:
	ElevatorHandler.debug_log("nav finish elevator npc=%s" % npc.name)
	_active_elevator_request = null
	target_path.remove_at(0)
	if target_path.is_empty():
		stop_navigation()
		target_reached_signal.emit()


func _append_connected_room(result: Array[RoomBase], room, floor_y: int) -> void:
	if room is RoomBase and _is_walkable_room_on_floor(room, floor_y) and room not in result:
		result.append(room)


func _get_walkable_room_on_position_floor(pos: Vector2) -> RoomBase:
	var floor_index: Vector2i = Building.round_floor_index_from_global_position(pos)
	var exact := Building.query.room_at_floor_position(pos) as RoomBase
	if exact != null:
		return exact if _is_walkable_room_on_floor(exact, floor_index.y) else null

	var closest_room: RoomBase = null
	var shortest_distance: float = INF
	if not Building.floors.has(floor_index.y):
		return null

	for x in Building.floors[floor_index.y]:
		var room := Building.floors[floor_index.y][x] as RoomBase
		if not _is_walkable_room_on_floor(room, floor_index.y):
			continue
		var distance := room.global_position.distance_to(pos)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_room = room

	return closest_room


func _is_walkable_room_on_floor(room: RoomBase, floor_y: int) -> bool:
	if room == null or room.data == null:
		return false
	return floor_y == room.y


func _get_room_center_floor_position(room: RoomBase, floor_y: int) -> Vector2:
	if room == null:
		return Vector2.ZERO
	var width := room.data.width if room.data != null else 1
	return Vector2(room.global_position.x + width * 24.0, _get_room_floor_y_world(room, floor_y))


func _get_room_random_floor_position(room: RoomBase, floor_y: int) -> Vector2:
	if room == null:
		return Vector2.ZERO
	var width := room.data.width if room.data != null else 1
	return Vector2(room.global_position.x + randi_range(4, width * 48 - 4), _get_room_floor_y_world(room, floor_y))


func _get_room_floor_y_world(room: RoomBase, floor_y: int) -> float:
	if room == null:
		return floor_y * -48.0
	return room.global_position.y - float(floor_y - room.y) * 48.0


func _draw_debug_path() -> void:
	if target_path.is_empty():
		return
	var prev := global_position
	var last := prev
	for phase : navigationPhase in target_path:
		var target : Vector2 = phase.last_waypoint() if phase is useStairsPhase else phase.target_location
		DebugDraw2D.line(prev, target, Color.CYAN)
		prev = target
		last = target
	DebugDraw2D.circle(last, 3.0, 8, Color.YELLOW)


func _draw_debug_line(start_pos: Vector2, goal_pos: Vector2, valid: bool) -> void:
	DebugDraw2D.line(start_pos, goal_pos, Color.GREEN if valid else Color.RED)


func _update_debug_inside_label() -> void:
	var text: String = "INSIDE" if _is_inside else "OUTSIDE"
	if _debug_inside_notification == null:
		_debug_inside_notification = UiNotifications.create_notification_dynamic(text, npc, Vector2(0, -48))
		_debug_inside_notification.is_permanent = true
		_debug_inside_notification.lifetime_left = INF
	else:
		var label: Label = _debug_inside_notification.instance.get_node("MarginContainer/HBoxContainer/Label")
		label.text = text

# phase data containers
class navigationPhase:
	var target_location : Vector2
	var inside = false
	signal on_finished_phase
		
class manualPhase:
	extends navigationPhase
	func trigger_manual_finish():
		on_finished_phase.emit()
		
class walkPhase:
	extends navigationPhase
	func _init(target):
		target_location = target
	
class useStairsPhase:
	extends navigationPhase
	var waypoints = []
	var current_index := 0

	func last_waypoint():
		return waypoints[waypoints.size()-1]

	func current_waypoint():
		return waypoints[current_index]

	func is_done() -> bool:
		return current_index >= waypoints.size()

class swapInOutSidewaysPhase:
	extends navigationPhase
	var entering : bool
	func _init(target, is_entering):
		target_location = target
		entering = is_entering

class useDoorSwapPhase:
	extends manualPhase
	var door_room : RoomBouncer
	var entering : bool
	func _init(door, is_entering):
		door_room = door
		entering = is_entering
		target_location = door.get_center_floor_position()

class useElevatorPhase:
	extends manualPhase
	var from_room : RoomElevator
	var to_room : RoomElevator
	func _init(from, to):
		from_room = from
		to_room = to
		target_location = from.get_boarding_position()
