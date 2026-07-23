extends Node2D

signal shafts_rebuilt

const ELEVATOR_ROOM_SCRIPT = preload("res://scripts/room_elevator.gd")
const SHAFT_CONTROLLER_SCRIPT = preload("res://scripts/elevator_shaft_controller.gd")

var debug_logging := true
var _controllers: Array = []
var _controller_by_room: Dictionary = {}
var _rebuild_pending := false
var _waiting_for_rebuild := false

func _ready() -> void:
	GlobalEventHandler.on_room_created_signal.connect(_on_rooms_changed)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_rooms_changed)
	call_deferred("rebuild_shafts")

func get_reachable_floors(room) -> Array:
	var controller = _controller_by_room.get(room, null)
	var result : Array = []
	if controller == null:
		result = [room.y]
	else:
		# the shaft rebuild is deferred (see _on_rooms_changed), so a room
		# just deleted elsewhere in this same shaft can still be sitting in
		# controller.rooms, not yet actually freed or already freed depending
		# on timing - never touch a stale entry's properties
		for r in controller.rooms:
			if is_instance_valid(r):
				result.append(r.y)
	debug_log("get_reachable_floors room=(%d,%d) controller=%s pending_rebuild=%s result=%s" % [
		room.x, room.y, str(controller), str(_rebuild_pending), str(result)
	])
	return result

func request_trip(npc: NPC, from_room, to_room):
	var controller = _controller_by_room.get(from_room, null)
	debug_log("request_trip npc=%s from=(%d,%d) to=(%d,%d) controller=%s" % [
		npc.name,
		from_room.x, from_room.y,
		to_room.x, to_room.y,
		str(controller)
	])
	return controller.request_trip(npc, from_room, to_room)

func rebuild_shafts() -> void:
	if _has_busy_controller():
		_rebuild_pending = true
		debug_log("rebuild_shafts delayed while busy")
		return
	_rebuild_pending = false
	debug_log("rebuild_shafts start")
	for controller in _controllers:
		controller.queue_free()
	_controllers.clear()
	_controller_by_room.clear()

	var rooms_by_x: Dictionary = {}
	for floor in Building.floors.values():
		for room in floor.values():
			if room.get_script() == ELEVATOR_ROOM_SCRIPT:
				if not rooms_by_x.has(room.x):
					rooms_by_x[room.x] = []
				rooms_by_x[room.x].append(room)

	for rooms in rooms_by_x.values():
		rooms.sort_custom(func(a, b): return a.y < b.y)
		var shaft_rooms: Array = []
		var previous_y := 0
		var has_previous := false
		for room in rooms:
			if has_previous and room.y != previous_y + 1:
				_create_controller(shaft_rooms)
				shaft_rooms = []
			shaft_rooms.append(room)
			previous_y = room.y
			has_previous = true
		_create_controller(shaft_rooms)
	shafts_rebuilt.emit()

func _create_controller(rooms: Array) -> void:
	if rooms.is_empty():
		return
	var controller = SHAFT_CONTROLLER_SCRIPT.new()
	add_child(controller)
	controller.setup(rooms)
	_controllers.append(controller)
	for room in rooms:
		_controller_by_room[room] = controller
	debug_log("rebuild_shafts done controllers=%d" % _controllers.size())

func _on_rooms_changed(_room = null) -> void:
	_rebuild_pending = true
	if not _waiting_for_rebuild:
		call_deferred("_flush_rebuild")

func _flush_rebuild() -> void:
	_waiting_for_rebuild = true
	while _rebuild_pending and _has_busy_controller():
		await get_tree().process_frame
	_waiting_for_rebuild = false
	if _rebuild_pending:
		rebuild_shafts()

func _has_busy_controller() -> bool:
	for controller in _controllers:
		if controller.is_busy():
			return true
	return false

func debug_log(message: String) -> void:
	if debug_logging:
		print("[Elevator] ", message)
