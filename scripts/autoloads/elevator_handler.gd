extends Node2D

signal shafts_rebuilt

const ELEVATOR_ROOM_SCRIPT = preload("res://scripts/room_elevator.gd")
const SHAFT_CONTROLLER_SCRIPT = preload("res://scripts/elevator_shaft_controller.gd")
const DEBUG_SHAFT_COLORS := [Color.CYAN, Color.MAGENTA, Color.LIME_GREEN, Color.ORANGE, Color.PINK, Color.YELLOW]

var debug_logging := true
var _debug_elevator := false
var _controllers: Array = []
var _controller_by_room: Dictionary = {}
var _shafts_rebuilt_pending := false

func _ready() -> void:
	GlobalEventHandler.on_room_created_signal.connect(_on_room_created)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_room_deleted)
	Console.add_command("debug_elevator", _console_toggle_debug_elevator, 0, 0, "Toggles shapes-only debug drawing of elevator shafts, cage state, queues, and requests.")
	call_deferred("rebuild_shafts")

func _process(_delta: float) -> void:
	if not _debug_elevator:
		return
	for i in _controllers.size():
		_controllers[i].debug_draw(DEBUG_SHAFT_COLORS[i % DEBUG_SHAFT_COLORS.size()])

func _console_toggle_debug_elevator() -> void:
	_debug_elevator = !_debug_elevator
	Console.print_line("Elevator debug draw " + ("ON" if _debug_elevator else "OFF"))

func get_reachable_floors(room) -> Array:
	var controller = _controller_by_room.get(room, null)
	var result : Array = []
	if controller == null:
		result = [room.y]
	else:
		for r in controller.rooms:
			if is_instance_valid(r):
				result.append(r.y)
	debug_log("get_reachable_floors room=(%d,%d) controller=%s result=%s" % [
		room.x, room.y, str(controller), str(result)
	])
	return result

func get_shaft_queue_count(room) -> int:
	var controller = _controller_by_room.get(room, null)
	if controller == null:
		return 0
	var count := 0
	for r in controller.rooms:
		if is_instance_valid(r):
			count += r.queue_up.size() + r.queue_down.size()
	return count

func request_trip(npc: NPC, from_room, to_room):
	var controller = _controller_by_room.get(from_room, null)
	debug_log("request_trip npc=%s from=(%d,%d) to=(%d,%d) controller=%s" % [
		npc.name,
		from_room.x, from_room.y,
		to_room.x, to_room.y,
		str(controller)
	])
	return controller.request_trip(npc, from_room, to_room)

func rebuild_shafts() -> void: # one-shot full scan, only used as the initial-load bootstrap - room add/remove is incremental below
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
	debug_log("controller created floors=%s controllers=%d" % [str(rooms.map(func(r): return r.y)), _controllers.size()])

# Deferred: during save load, Building.set_room() emits this before the room's x/y
# are patched in by a second pass right after (see save_handler.gd) - reading them
# inline here would see null.
func _on_room_created(room) -> void:
	call_deferred("_handle_room_created", room)

func _on_room_deleted(room) -> void:
	call_deferred("_handle_room_deleted", room)

func _handle_room_created(room) -> void:
	if not is_instance_valid(room) or room.get_script() != ELEVATOR_ROOM_SCRIPT:
		return
	var above_controller = _find_controller_with_room_at(room.x, room.y - 1)
	var below_controller = _find_controller_with_room_at(room.x, room.y + 1)
	if above_controller != null and below_controller != null and above_controller != below_controller:
		_merge_controllers(above_controller, below_controller, room)
	elif above_controller != null:
		_attach_room(above_controller, room)
	elif below_controller != null:
		_attach_room(below_controller, room)
	else:
		_create_controller([room])
	_request_shafts_rebuilt()

func _handle_room_deleted(room) -> void:
	var controller = _controller_by_room.get(room, null)
	if controller == null:
		return
	_controller_by_room.erase(room)
	controller.remove_room(room)
	if controller.rooms.is_empty():
		_controllers.erase(controller)
		controller.queue_free()
	else:
		_split_if_disconnected(controller)
	_request_shafts_rebuilt()

# Coalesces bursts of shaft changes (e.g. every room of a multi-floor shaft loading in
# the same frame) into one emission - each one is a full connector re-mirror across the
# whole building (see _on_elevator_shafts_rebuilt), so N rooms changing in one frame
# shouldn't mean N full re-mirrors.
func _request_shafts_rebuilt() -> void:
	if _shafts_rebuilt_pending:
		return
	_shafts_rebuilt_pending = true
	call_deferred("_flush_shafts_rebuilt")

func _flush_shafts_rebuilt() -> void:
	_shafts_rebuilt_pending = false
	shafts_rebuilt.emit()

func _find_controller_with_room_at(x: int, y: int):
	for controller in _controllers:
		var candidate = controller.room_by_floor.get(y)
		if candidate != null and candidate.x == x:
			return controller
	return null

func _attach_room(controller, room) -> void:
	controller.add_room(room)
	_controller_by_room[room] = controller
	debug_log("attach room floor=%d to existing controller" % room.y)

func _merge_controllers(keep_controller, other_controller, bridging_room) -> void:
	debug_log("merge controllers via bridging room floor=%d" % bridging_room.y)
	keep_controller.add_room(bridging_room)
	_controller_by_room[bridging_room] = keep_controller
	for room in other_controller.rooms.duplicate():
		keep_controller.add_room(room)
		_controller_by_room[room] = keep_controller
	_controllers.erase(other_controller)
	other_controller.queue_free()
	debug_log("merge done floors=%s controllers=%d" % [str(keep_controller.rooms.map(func(r): return r.y)), _controllers.size()])

func _split_if_disconnected(controller) -> void:
	var runs: Array = []
	var current_run: Array = []
	var previous_y := 0
	var has_previous := false
	for room in controller.rooms:
		if has_previous and room.y != previous_y + 1:
			runs.append(current_run)
			current_run = []
		current_run.append(room)
		previous_y = room.y
		has_previous = true
	if not current_run.is_empty():
		runs.append(current_run)
	if runs.size() <= 1:
		return

	var cage_floor: int = controller.get_current_floor_y()
	var keep_run: Array = runs[0]
	for run in runs:
		for r in run:
			if r.y == cage_floor:
				keep_run = run
				break

	debug_log("split shaft into %d segments, keeping cage's segment" % runs.size())
	for run in runs:
		if run == keep_run:
			continue
		for room in run:
			controller.remove_room(room)
		_create_controller(run)

func debug_log(message: String) -> void:
	if debug_logging:
		print("[Elevator] ", message)
