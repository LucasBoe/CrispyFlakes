extends Node2D
class_name ElevatorShaftController

const CAGE_SCENE := preload("res://scenes/elevator_cage.tscn")
const RIDE_REQUEST_SCRIPT := preload("res://scripts/elevator_ride_request.gd")
const CAGE_SPEED := 48.0
const WALK_SPEED := 32.0

var rooms: Array = []
var room_by_floor: Dictionary = {}
var cages: Array = []
var _queue: Array = []
var _running := false

func setup(shaft_rooms: Array) -> void:
	rooms = shaft_rooms.duplicate()
	rooms.sort_custom(func(a, b): return a.y < b.y)
	room_by_floor.clear()
	for room in rooms:
		room_by_floor[room.y] = room
	ElevatorHandler.debug_log("shaft setup floors=%s" % str(rooms.map(func(room): return room.y)))

	var cage = CAGE_SCENE.instantiate()
	add_child(cage)
	cages = [cage]
	cage.global_position = rooms[0].get_cage_stop_position()

func has_room(room) -> bool:
	return room in rooms

func is_busy() -> bool:
	return _running or not _queue.is_empty()

func request_trip(npc: NPC, from_room, to_room):
	var request = RIDE_REQUEST_SCRIPT.new()
	request.npc = npc
	request.from_room = from_room
	request.to_room = to_room
	_queue.append(request)
	ElevatorHandler.debug_log("queue trip npc=%s from=%d to=%d queue=%d" % [npc.name, from_room.y, to_room.y, _queue.size()])
	if not _running:
		call_deferred("_run_queue")
	return request

func _run_queue() -> void:
	if _running or _queue.is_empty():
		return
	_running = true
	var request = _queue.pop_front()
	ElevatorHandler.debug_log("start trip npc=%s from=%d to=%d remaining_queue=%d" % [request.npc.name, request.from_room.y, request.to_room.y, _queue.size()])
	await _serve_request(request)
	_running = false
	ElevatorHandler.debug_log("finish trip npc=%s" % request.npc.name)
	if not _queue.is_empty():
		call_deferred("_run_queue")

func _serve_request(request) -> void:
	var cage = cages[0]
	ElevatorHandler.debug_log("move cage to pickup floor=%d npc=%s" % [request.from_room.y, request.npc.name])
	await cage.move_to(request.from_room.get_cage_stop_position(), CAGE_SPEED)
	ElevatorHandler.debug_log("open doors pickup floor=%d npc=%s" % [request.from_room.y, request.npc.name])
	await cage.open_doors()
	ElevatorHandler.debug_log("walk to boarding npc=%s pos=%s" % [request.npc.name, str(request.from_room.get_boarding_position())])
	await _walk_npc_to(request.npc, request.from_room.get_boarding_position())
	ElevatorHandler.debug_log("walk into cage npc=%s pos=%s" % [request.npc.name, str(cage.get_passenger_position())])
	await _walk_npc_to(request.npc, cage.get_passenger_position())
	cage.board(request.npc)
	ElevatorHandler.debug_log("close doors with passenger npc=%s" % request.npc.name)
	await cage.close_doors()
	ElevatorHandler.debug_log("move cage to target floor=%d npc=%s" % [request.to_room.y, request.npc.name])
	await cage.move_to(request.to_room.get_cage_stop_position(), CAGE_SPEED)
	ElevatorHandler.debug_log("open doors target floor=%d npc=%s" % [request.to_room.y, request.npc.name])
	await cage.open_doors()
	request.npc.global_position = cage.get_passenger_position()
	cage.unboard(request.npc)
	ElevatorHandler.debug_log("walk out npc=%s pos=%s" % [request.npc.name, str(request.to_room.get_exit_position())])
	await _walk_npc_to(request.npc, request.to_room.get_exit_position())
	ElevatorHandler.debug_log("close doors after exit npc=%s" % request.npc.name)
	await cage.close_doors()
	ElevatorHandler.debug_log("emit finished npc=%s" % request.npc.name)
	request.finished.emit()

func _walk_npc_to(npc: NPC, target: Vector2) -> void:
	ElevatorHandler.debug_log("walk start npc=%s from=%s to=%s" % [npc.name, str(npc.global_position), str(target)])
	while npc.global_position.distance_to(target) > 1.0:
		npc.Animator.direction = target - npc.global_position
		npc.global_position = npc.global_position.move_toward(target, get_process_delta_time() * WALK_SPEED * npc.get_move_speed_multiplier())
		await get_tree().process_frame
	npc.global_position = target
	npc.Animator.direction = Vector2.ZERO
	ElevatorHandler.debug_log("walk done npc=%s at=%s" % [npc.name, str(target)])
