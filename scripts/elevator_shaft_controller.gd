extends Node2D
class_name ElevatorShaftController

const CAGE_SCENE := preload("res://scenes/elevator_cage.tscn")
const RIDE_REQUEST_SCRIPT := preload("res://scripts/elevator_ride_request.gd")
const CAGE_SPEED := 48.0
const WALK_SPEED := 32.0

var rooms: Array = []
var room_by_floor: Dictionary = {}
var cages: Array = []

var _direction: int = 0
var _current_floor_y: int = 0
var _run_active := false
var _pending_requests: Array = []
var _boarded_requests: Dictionary = {}

func setup(shaft_rooms: Array) -> void:
	rooms = shaft_rooms.duplicate()
	rooms.sort_custom(func(a, b): return a.y < b.y)
	room_by_floor.clear()
	for room in rooms:
		room_by_floor[room.y] = room
	ElevatorHandler.debug_log("shaft setup floors=%s" % str(rooms.map(func(room): return room.y)))

	#cages should be placed MANUALLY as separate infrastructure, each shaft should be able to contain multiple cages
	var cage = CAGE_SCENE.instantiate()
	add_child(cage)
	cages = [cage]
	cage.global_position = rooms[0].get_cage_stop_position()
	_current_floor_y = rooms[0].y

func add_room(room) -> void:
	if room in rooms:
		return
	rooms.append(room)
	rooms.sort_custom(func(a, b): return a.y < b.y)
	room_by_floor[room.y] = room
	ElevatorHandler.debug_log("shaft add_room floor=%d floors=%s" % [room.y, str(rooms.map(func(r): return r.y))])

func remove_room(room) -> void:
	rooms.erase(room)
	room_by_floor.erase(room.y)
	ElevatorHandler.debug_log("shaft remove_room floor=%d floors=%s" % [room.y, str(rooms.map(func(r): return r.y))])

func get_current_floor_y() -> int:
	return _current_floor_y

func _emit_finished(request: ElevatorRideRequest) -> void:
	request.finished.emit()

func request_trip(npc: NPC, from_room, to_room) -> ElevatorRideRequest:
	var request: ElevatorRideRequest = RIDE_REQUEST_SCRIPT.new(npc, from_room, to_room)
	if not is_instance_valid(npc) or not is_instance_valid(from_room) or not is_instance_valid(to_room):
		ElevatorHandler.debug_log("skip trip - npc or room invalid at request time")
		call_deferred("_emit_finished", request) # deferred so the caller can connect to `finished` first
		return request
	_pending_requests.append(request)
	from_room.join_queue(npc, request.direction)
	ElevatorHandler.debug_log("queue trip npc=%s from=%d to=%d direction=%d pending=%d" % [
		npc.name, from_room.y, to_room.y, request.direction, _pending_requests.size()
	])
	if not _run_active:
		call_deferred("_run_cycle")
	return request

func _run_cycle() -> void: # SCAN/LOOK: keep moving one way, servicing stops, until nothing's left ahead, then reverse or idle
	if _run_active:
		return
	_run_active = true
	ElevatorHandler.debug_log("run_cycle start floor=%d pending=%d boarded=%d" % [_current_floor_y, _pending_requests.size(), _boarded_requests.size()])
	var stall_guard := 0 # backstop against a hard engine freeze if a future logic gap ever produces a no-progress loop
	var was_stationary := true # tracks whether the cage was just standing still, for easing the next hop's departure
	while true:
		stall_guard += 1
		if stall_guard > 64:
			ElevatorHandler.debug_log("run_cycle stalled with no progress - forcing idle floor=%d direction=%d pending=%d boarded=%d" % [
				_current_floor_y, _direction, _pending_requests.size(), _boarded_requests.size()
			])
			break

		_prune_invalid_pending()

		if _direction == 0:
			_direction = _pick_initial_direction()
			if _direction == 0:
				break
			ElevatorHandler.debug_log("picked direction=%d from floor=%d" % [_direction, _current_floor_y])

		if room_by_floor.has(_current_floor_y) and _floor_has_stop_demand(_current_floor_y, _direction):
			await _service_stop(room_by_floor[_current_floor_y])
			was_stationary = true
			stall_guard = 0

		if _has_demand_ahead(_direction):
			var next_floor: int = _current_floor_y + _direction
			if room_by_floor.has(next_floor):
				var will_stop: bool = _floor_has_stop_demand(next_floor, _direction)
				ElevatorHandler.debug_log("cage travel floor=%d -> %d" % [_current_floor_y, next_floor])
				await cages[0].move_to(room_by_floor[next_floor].get_cage_stop_position(), CAGE_SPEED, was_stationary, will_stop)
				_current_floor_y = next_floor
				was_stationary = false
				stall_guard = 0
				continue

		if _has_demand_ahead(-_direction):
			ElevatorHandler.debug_log("reversing direction=%d -> %d at floor=%d" % [_direction, -_direction, _current_floor_y])
			_direction = -_direction
			continue

		_direction = 0
	ElevatorHandler.debug_log("run_cycle idle floor=%d pending=%d boarded=%d" % [_current_floor_y, _pending_requests.size(), _boarded_requests.size()])
	_run_active = false

func _prune_invalid_pending() -> void:
	var i: int = _pending_requests.size() - 1
	while i >= 0:
		var request: ElevatorRideRequest = _pending_requests[i]
		if not is_instance_valid(request.npc) or not is_instance_valid(request.from_room) or not is_instance_valid(request.to_room):
			_pending_requests.remove_at(i)
			ElevatorHandler.debug_log("prune invalid pending request npc_valid=%s from_valid=%s to_valid=%s" % [
				is_instance_valid(request.npc), is_instance_valid(request.from_room), is_instance_valid(request.to_room)
			])
			request.finished.emit()
		i -= 1

func _floor_has_stop_demand(floor_y: int, direction: int) -> bool:
	for request in _boarded_requests.values():
		if is_instance_valid(request.to_room) and request.to_room.y == floor_y:
			return true # exits are direction-agnostic
	for request in _pending_requests:
		if request.from_room.y == floor_y and request.direction == direction:
			return true
	return false

# Pending requests are NOT gated by direction here - a lone request to go down from a
# floor above an idle cage still needs the cage to travel up to reach it first. Actually
# stopping/boarding once there is the separate, direction-gated call above.
func _has_demand_ahead(direction: int) -> bool:
	if direction == 0:
		return false
	for request in _boarded_requests.values():
		if is_instance_valid(request.to_room) and signi(request.to_room.y - _current_floor_y) == direction:
			return true
	for request in _pending_requests:
		if signi(request.from_room.y - _current_floor_y) == direction:
			return true
	return false

func _pick_initial_direction() -> int:
	var best_direction: int = 0
	var best_distance: int = -1
	for request in _pending_requests:
		var floor_y: int = request.from_room.y
		var distance: int = floor_y - _current_floor_y
		if distance == 0:
			return request.direction # already here - go their way without moving
		var distance_abs: int = abs(distance)
		if best_distance < 0 or distance_abs < best_distance:
			best_distance = distance_abs
			best_direction = signi(distance)
	return best_direction

func _service_stop(room) -> void:
	var cage = cages[0]
	ElevatorHandler.debug_log("service stop floor=%d direction=%d" % [room.y, _direction])
	await cage.open_doors()
	await _exit_passengers(room)
	await _board_passengers(room)
	await cage.close_doors()

func _exit_passengers(room) -> void:
	var exiting: Array = []
	for npc in _boarded_requests.keys():
		var request: ElevatorRideRequest = _boarded_requests[npc]
		if is_instance_valid(request.to_room) and request.to_room == room:
			exiting.append(npc)
	if exiting.is_empty():
		return
	ElevatorHandler.debug_log("exiting count=%d at floor=%d" % [exiting.size(), room.y])
	var remaining: Array = [exiting.size()]
	for npc in exiting:
		_finish_exit(npc, room, remaining)
	while remaining[0] > 0:
		await get_tree().process_frame

func _finish_exit(npc: NPC, room, remaining: Array) -> void:
	var request: ElevatorRideRequest = _boarded_requests[npc]
	_boarded_requests.erase(npc)
	if not is_instance_valid(npc):
		request.finished.emit()
		remaining[0] -= 1
		return
	var cage = cages[0]
	npc.global_position = cage.get_passenger_position(npc)
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	cage.unboard(npc)
	ElevatorHandler.debug_log("walk out npc=%s pos=%s" % [npc.name, str(room.get_exit_position())])
	await npc.Navigation.force_walk_to(room.get_exit_position(), WALK_SPEED)
	request.finished.emit()
	remaining[0] -= 1

func _board_passengers(room) -> void:
	var boarding: Array = []
	for request in _pending_requests:
		if request.from_room == room and request.direction == _direction:
			boarding.append(request)
	if boarding.is_empty():
		return
	ElevatorHandler.debug_log("boarding count=%d at floor=%d" % [boarding.size(), room.y])
	for request in boarding:
		_pending_requests.erase(request)

	var cage = cages[0]
	var remaining: Array = [boarding.size()]
	var next_slot: int = cage.passengers.size()
	for request in boarding:
		_finish_board(request, room, cage, next_slot, remaining)
		next_slot += 1
	while remaining[0] > 0:
		await get_tree().process_frame

func _finish_board(request: ElevatorRideRequest, room, cage: ElevatorCage, slot: int, remaining: Array) -> void:
	var npc: NPC = request.npc
	if not is_instance_valid(npc):
		remaining[0] -= 1
		return
	room.leave_queue(npc, request.direction)
	ElevatorHandler.debug_log("walk to boarding npc=%s pos=%s" % [npc.name, str(room.get_boarding_position())])
	await npc.Navigation.force_walk_to(room.get_boarding_position(), WALK_SPEED)
	ElevatorHandler.debug_log("walk into cage npc=%s slot=%d" % [npc.name, slot])
	await npc.Navigation.force_walk_to(cage.global_position + cage.slot_offset(slot), WALK_SPEED)
	cage.board(npc)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT) # same as tables/gambling - keeps them behind the closed door
	_boarded_requests[npc] = request
	remaining[0] -= 1

const DEBUG_ARROW_LENGTH := 10.0
const DEBUG_ARROW_HEAD_SIZE := 3.0 # DebugDraw2D.arrow() defaults to 25% of shaft length otherwise - huge on a long route
const DEBUG_UP_COLOR := Color.CYAN
const DEBUG_DOWN_COLOR := Color.ORANGE
const DEBUG_QUEUE_COLOR := Color.WHITE

func debug_draw(shaft_color: Color) -> void:
	if rooms.is_empty() or cages.is_empty():
		return
	var cage: ElevatorCage = cages[0]

	var top_pos: Vector2 = rooms[rooms.size() - 1].get_cage_stop_position() + Vector2(0, -48.0)
	var bottom_pos: Vector2 = rooms[0].get_cage_stop_position()
	DebugDraw2D.rect((top_pos + bottom_pos) * 0.5, Vector2(6.0, absf(top_pos.y - bottom_pos.y) + 48.0), shaft_color, 1.0)

	var direction_color: Color = DEBUG_UP_COLOR if _direction > 0 else (DEBUG_DOWN_COLOR if _direction < 0 else Color.GRAY)
	DebugDraw2D.circle_filled(cage.global_position, 5.0, 12, direction_color)
	for i in cage.passengers.size():
		DebugDraw2D.circle_filled(cage.global_position + Vector2(0.0, -9.0 - i * 4.0), 1.5, 6, direction_color)

	for room in rooms:
		if not (room is RoomElevator):
			continue
		for npc in room.queue_up:
			DebugDraw2D.circle_filled(room.get_queue_position(npc, 1), 2.0, 8, DEBUG_QUEUE_COLOR)
		for npc in room.queue_down:
			DebugDraw2D.circle_filled(room.get_queue_position(npc, -1), 2.0, 8, DEBUG_QUEUE_COLOR)

	for request in _pending_requests:
		if not is_instance_valid(request.from_room):
			continue
		var color: Color = DEBUG_UP_COLOR if request.direction > 0 else DEBUG_DOWN_COLOR
		var origin: Vector2 = request.from_room.get_cage_stop_position()
		DebugDraw2D.arrow(origin, origin + Vector2(0.0, -DEBUG_ARROW_LENGTH * request.direction), color, 1.0, 0.0, DEBUG_ARROW_HEAD_SIZE)
