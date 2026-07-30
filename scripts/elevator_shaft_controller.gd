extends Node2D
class_name ElevatorShaftController

const RIDE_REQUEST_SCRIPT := preload("res://scripts/elevator_ride_request.gd")

var rooms: Array = []
var room_by_floor: Dictionary = {}
var cages: Array = []
var pending_requests: Array = []

func setup(shaft_rooms: Array) -> void:
	rooms = shaft_rooms.duplicate()
	rooms.sort_custom(func(a, b): return a.y < b.y)
	room_by_floor.clear()
	for room in rooms:
		room_by_floor[room.y] = room
	ElevatorHandler.debug_log("shaft setup floors=%s" % str(rooms.map(func(room): return room.y)))

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

# Cages are placed/removed as their own infrastructure, independent of the shaft's rooms -
# a shaft can exist with zero, one, or several cages.
func add_cage(cage: ElevatorCage) -> void:
	if cage in cages:
		return
	cage.controller = self
	cages.append(cage)
	cage.snap_weight_to_current_position() # controller wasn't set yet during cage.place(), so these missed their first update
	cage.snap_big_wheel_to_shaft()
	ElevatorHandler.debug_log("shaft add_cage floor=%d cages=%d" % [cage.current_floor_y, cages.size()])
	cage.request_run()

func remove_cage(cage: ElevatorCage) -> void:
	cages.erase(cage)
	ElevatorHandler.debug_log("shaft remove_cage cages=%d" % cages.size())

func get_current_floor_y() -> int: # used to decide which split segment a cage belongs to
	return cages[0].current_floor_y if not cages.is_empty() else (rooms[0].y if not rooms.is_empty() else 0)

func _emit_finished(request: ElevatorRideRequest) -> void:
	request.finished.emit()

func request_trip(npc: NPC, from_room, to_room) -> ElevatorRideRequest:
	var request: ElevatorRideRequest = RIDE_REQUEST_SCRIPT.new(npc, from_room, to_room)
	if not is_instance_valid(npc) or not is_instance_valid(from_room) or not is_instance_valid(to_room):
		ElevatorHandler.debug_log("skip trip - npc or room invalid at request time")
		call_deferred("_emit_finished", request) # deferred so the caller can connect to `finished` first
		return request
	pending_requests.append(request)
	from_room.join_queue(npc, request.direction)
	ElevatorHandler.debug_log("queue trip npc=%s from=%d to=%d direction=%d pending=%d" % [
		npc.name, from_room.y, to_room.y, request.direction, pending_requests.size()
	])
	if cages.is_empty():
		ElevatorHandler.debug_log("WARNING: shaft has no cage placed on it - this request (and any others) will never be serviced until one is placed")
	# wake every idle cage - whichever gets there first claims it (see ElevatorCage._run_cycle)
	for cage in cages:
		cage.request_run()
	return request

# Called when the requesting NPC's navigation gets interrupted before the ride happened
# (job reassignment, fight, drag, etc.) - without this the request sits in pending_requests
# forever with a still-connected `finished` signal that would later fire into whatever
# unrelated navigation state the NPC has moved on to.
func cancel_trip(request: ElevatorRideRequest) -> void:
	pending_requests.erase(request)
	if is_instance_valid(request.from_room):
		request.from_room.leave_queue(request.npc, request.direction)
	for cage: ElevatorCage in cages:
		if is_instance_valid(cage) and cage.cancel_request(request):
			return

func prune_invalid_pending() -> void:
	var i: int = pending_requests.size() - 1
	while i >= 0:
		var request: ElevatorRideRequest = pending_requests[i]
		if not is_instance_valid(request.npc) or not is_instance_valid(request.from_room) or not is_instance_valid(request.to_room):
			pending_requests.remove_at(i)
			ElevatorHandler.debug_log("prune invalid pending request npc_valid=%s from_valid=%s to_valid=%s" % [
				is_instance_valid(request.npc), is_instance_valid(request.from_room), is_instance_valid(request.to_room)
			])
			request.finished.emit()
		i -= 1

const DEBUG_UP_COLOR := Color.CYAN
const DEBUG_DOWN_COLOR := Color.ORANGE
const DEBUG_QUEUE_COLOR := Color.WHITE
const DEBUG_ARROW_LENGTH := 10.0
const DEBUG_ARROW_HEAD_SIZE := 3.0 # DebugDraw2D.arrow() defaults to 25% of shaft length otherwise - huge on a long route

func debug_draw(shaft_color: Color) -> void:
	if rooms.is_empty():
		return

	var top_pos: Vector2 = rooms[rooms.size() - 1].get_cage_stop_position() + Vector2(0, -48.0)
	var bottom_pos: Vector2 = rooms[0].get_cage_stop_position()
	DebugDraw2D.rect((top_pos + bottom_pos) * 0.5, Vector2(6.0, absf(top_pos.y - bottom_pos.y) + 48.0), shaft_color, 1.0)

	for cage in cages:
		cage.debug_draw()

	for room in rooms:
		if not (room is RoomElevator):
			continue
		for npc in room.queue_up:
			DebugDraw2D.circle_filled(room.get_queue_position(npc, 1), 2.0, 8, DEBUG_QUEUE_COLOR)
		for npc in room.queue_down:
			DebugDraw2D.circle_filled(room.get_queue_position(npc, -1), 2.0, 8, DEBUG_QUEUE_COLOR)

	for request in pending_requests:
		if not is_instance_valid(request.from_room):
			continue
		var color: Color = DEBUG_UP_COLOR if request.direction > 0 else DEBUG_DOWN_COLOR
		var origin: Vector2 = request.from_room.get_cage_stop_position()
		DebugDraw2D.arrow(origin, origin + Vector2(0.0, -DEBUG_ARROW_LENGTH * request.direction), color, 1.0, 0.0, DEBUG_ARROW_HEAD_SIZE)
