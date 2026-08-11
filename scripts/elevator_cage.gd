extends Node2D
class_name ElevatorCage

const CAGE_SPEED := 48.0
const WALK_SPEED := 32.0
const WEIGHT_SCENE := preload("res://scenes/elevator_weight.tscn")
const BIG_WHEEL_TEXTURE := preload("res://assets/sprites/elevator_wheel_spritesheet.png")
const SMALL_WHEEL_TEXTURE := preload("res://assets/sprites/elevator_wheel_small_spritesheet.png")
const BIG_WHEEL_HFRAMES := 4
const SMALL_WHEEL_HFRAMES := 2
const SMALL_WHEEL_SPACING := 11.0

@onready var cab: Sprite2D = $Cab

var controller: ElevatorShaftController # set by ElevatorShaftController.add_cage()
var passengers: Array[NPC] = []
var _passenger_offsets: Dictionary = {}
var _passenger_slots: Dictionary = {}

var direction: int = 0
var current_floor_y: int = 0
var run_active := false
var boarded_requests: Dictionary = {}

var weight: Sprite2D # own counterweight, sits at the shaft's mirrored height - not a child, since a child's position is relative to the cage, not independent of it
var big_wheel: Sprite2D # pulley at the top of the shaft - fixed position (like weight, not a child), only its frame animates
var small_wheel_a: Sprite2D
var small_wheel_b: Sprite2D

const ROPE_COLOR := Color("524e80")
var cage_rope: PixelLine
var weight_rope: PixelLine

func _log(message: String) -> void:
	ElevatorHandler.debug_log("[%s] %s" % [name, message])

func _ready() -> void:
	cab.frame = 0 # set directly, not animated - see _animate_frames' concurrency guard below for why
	cage_rope = PixelLine.new()
	cage_rope.line_color = ROPE_COLOR
	cage_rope.position = Vector2(0, -46)
	add_child(cage_rope)

	small_wheel_a = Sprite2D.new()
	small_wheel_a.texture = SMALL_WHEEL_TEXTURE
	small_wheel_a.hframes = SMALL_WHEEL_HFRAMES
	small_wheel_a.position = Vector2(-SMALL_WHEEL_SPACING / 2.0, 4.0)
	add_child(small_wheel_a)

	small_wheel_b = Sprite2D.new()
	small_wheel_b.texture = SMALL_WHEEL_TEXTURE
	small_wheel_b.hframes = SMALL_WHEEL_HFRAMES
	small_wheel_b.position = Vector2(SMALL_WHEEL_SPACING / 2.0, 4.0)
	add_child(small_wheel_b)

func _exit_tree() -> void:
	if is_instance_valid(weight):
		weight.queue_free()
	if is_instance_valid(big_wheel):
		big_wheel.queue_free()

func _process(_delta: float) -> void:
	for npc in passengers:
		if is_instance_valid(npc):
			npc.global_position = global_position + _passenger_offsets[npc]
	snap_weight_to_current_position()
	snap_big_wheel_to_shaft()
	_update_ropes()
	_update_wheel_frames()

const WEIGHT_OFFSET := 17.0 # how far off-center a weight (and its cable) runs, alternating left/right per cage
const BIG_WHEEL_OFFSET := 8.0 # sits halfway between the cage's own cable (center) and the weight's cable

# Cages share a shaft but each keeps its own weight out of the way by running it up/down a
# side track instead of straight behind the cage - first cage's weight on the left, second's
# on the right, alternating from there.
func _get_side_sign() -> float:
	if controller == null:
		return 0.0
	var index := controller.cages.find(self)
	if index < 0:
		return 0.0
	return 1.0 if index % 2 == 1 else -1.0

# The counterweight hangs on the opposite end of the same cable over a pulley at the top
# of the shaft - as the cage rises, the weight falls by the same amount, and vice versa.
# Mirroring cage_y around the midpoint of the shaft's vertical extent gives exactly that:
# cage at the bottom -> weight at the top, cage at the top -> weight at the bottom.
func snap_weight_to_current_position() -> void:
	if weight == null or controller == null or controller.rooms.is_empty():
		return
	var bottom_y: float = controller.rooms[0].get_cage_stop_position().y
	var top_y: float = controller.rooms[controller.rooms.size() - 1].get_cage_stop_position().y
	weight.global_position = Vector2(global_position.x + _get_side_sign() * WEIGHT_OFFSET, bottom_y + top_y - global_position.y)

# Fixed at the shaft's top, over which the cage/weight cable runs - re-anchored every frame
# since a shaft's top room can change (rooms added/removed/split/merged).
func snap_big_wheel_to_shaft() -> void:
	if big_wheel == null or controller == null or controller.rooms.is_empty():
		return
	var top: Vector2 = controller.rooms[controller.rooms.size() - 1].get_cage_stop_position() + Vector2(0, -40)
	big_wheel.global_position = top + Vector2(_get_side_sign() * BIG_WHEEL_OFFSET, 0)

# Both ropes run up to the same pulley point at the top of the shaft, one from the cage,
# one from the weight. The weight's rope shares its side offset so it hangs straight.
func _update_ropes() -> void:
	if controller == null or controller.rooms.is_empty():
		return
	var top: Vector2 = controller.rooms[controller.rooms.size() - 1].get_cage_stop_position() + Vector2(0, -40)
	cage_rope.target_position = top
	if weight_rope != null:
		weight_rope.target_position = top + Vector2(_get_side_sign() * WEIGHT_OFFSET, 0)

# Wheels only spin while the lift is actually moving, and spin proportionally to how fast -
# both fall out for free by driving the frame purely off the cage's own position instead of
# a separate timer: a stopped cage has an unchanging position, so the frame stops changing
# too, and a faster-moving cage covers more distance (and thus more of the modulo cycle) per
# frame. Using position-within-the-current-room (not raw world y) keeps the cycle length
# identical on every floor regardless of the room's absolute position in the shaft.
func _update_wheel_frames() -> void:
	var phase: float = fposmod(global_position.y, 48.0) / 24.0
	if big_wheel != null:
		big_wheel.frame = int(phase * BIG_WHEEL_HFRAMES) % BIG_WHEEL_HFRAMES
	small_wheel_a.frame = int(phase * SMALL_WHEEL_HFRAMES) % SMALL_WHEEL_HFRAMES
	small_wheel_b.frame = int(phase * SMALL_WHEEL_HFRAMES) % SMALL_WHEEL_HFRAMES

func place(start_room) -> void:
	global_position = start_room.get_cage_stop_position()
	current_floor_y = start_room.y
	weight = WEIGHT_SCENE.instantiate() as Sprite2D
	get_parent().add_child(weight)
	weight_rope = PixelLine.new()
	weight_rope.line_color = ROPE_COLOR
	weight_rope.position = Vector2(0, -8)
	weight.add_child(weight_rope)
	big_wheel = Sprite2D.new()
	big_wheel.texture = BIG_WHEEL_TEXTURE
	big_wheel.hframes = BIG_WHEEL_HFRAMES
	big_wheel.z_index = -90 # top-level sibling, not a cage child, so it needs its own z (matching cage/weight) or it renders in front of the shaft instead of inside it
	get_parent().add_child(big_wheel)
	snap_weight_to_current_position()
	snap_big_wheel_to_shaft()
	_update_ropes()

func request_run() -> void:
	if not run_active:
		call_deferred("_run_cycle")

func is_busy() -> bool:
	return run_active or not boarded_requests.is_empty()

# SCAN/LOOK: keep moving one way, servicing stops, until nothing's left ahead for THIS cage,
# then reverse or idle. Pulls from the shaft's shared pending pool (controller.pending_requests) -
# with multiple cages on one shaft, more than one cage can independently head toward the same
# pending request; whichever boards it first erases it from the pool, the other just finds no
# demand left when it arrives. Wasted trips are possible but harmless - fine for now since same-
# floor cage collision isn't handled yet either.
func _run_cycle() -> void:
	if run_active:
		return
	run_active = true
	_log("cage run_cycle start floor=%d pending=%d boarded=%d" % [current_floor_y, controller.pending_requests.size(), boarded_requests.size()])
	var stall_guard := 0 # backstop against a hard engine freeze if a future logic gap ever produces a no-progress loop
	var was_stationary := true # tracks whether the cage was just standing still, for easing the next hop's departure
	while true:
		stall_guard += 1
		if stall_guard > 64:
			_log("cage run_cycle stalled with no progress - forcing idle floor=%d direction=%d" % [current_floor_y, direction])
			break

		controller.prune_invalid_pending()

		if direction == 0:
			direction = _pick_initial_direction()
			if direction == 0:
				break
			_log("cage picked direction=%d from floor=%d" % [direction, current_floor_y])

		if controller.room_by_floor.has(current_floor_y) and _floor_has_stop_demand(current_floor_y, direction):
			await _service_stop(controller.room_by_floor[current_floor_y])
			was_stationary = true
			stall_guard = 0

		if _has_demand_ahead(direction):
			var next_floor: int = current_floor_y + direction
			if controller.room_by_floor.has(next_floor):
				var will_stop: bool = _floor_has_stop_demand(next_floor, direction)
				_log("cage travel floor=%d -> %d" % [current_floor_y, next_floor])
				await move_to(controller.room_by_floor[next_floor].get_cage_stop_position(), CAGE_SPEED, was_stationary, will_stop)
				current_floor_y = next_floor
				was_stationary = false
				stall_guard = 0
				continue

		if _has_demand_ahead(-direction):
			_log("cage reversing direction=%d -> %d at floor=%d" % [direction, -direction, current_floor_y])
			direction = -direction
			continue

		direction = 0
	_log("cage run_cycle idle floor=%d boarded=%d" % [current_floor_y, boarded_requests.size()])
	run_active = false

func _floor_has_stop_demand(floor_y: int, dir: int) -> bool:
	for request in boarded_requests.values():
		if is_instance_valid(request.to_room) and request.to_room.y == floor_y:
			return true # exits are direction-agnostic
	if not controller.is_powered():
		return false
	for request in controller.pending_requests:
		if request.from_room.y == floor_y and request.direction == dir:
			return true
	return false

# Pending requests are NOT gated by direction here - a lone request to go down from a
# floor above an idle cage still needs the cage to travel up to reach it first. Actually
# stopping/boarding once there is the separate, direction-gated call above.
func _has_demand_ahead(dir: int) -> bool:
	if dir == 0:
		return false
	for request in boarded_requests.values():
		if is_instance_valid(request.to_room) and signi(request.to_room.y - current_floor_y) == dir:
			return true
	if not controller.is_powered():
		return false
	for request in controller.pending_requests:
		if signi(request.from_room.y - current_floor_y) == dir:
			return true
	return false

func _pick_initial_direction() -> int:
	if not controller.is_powered():
		return 0
	var best_direction: int = 0
	var best_distance: int = -1
	for request in controller.pending_requests:
		var floor_y: int = request.from_room.y
		var distance: int = floor_y - current_floor_y
		if distance == 0:
			return request.direction # already here - go their way without moving
		var distance_abs: int = abs(distance)
		if best_distance < 0 or distance_abs < best_distance:
			best_distance = distance_abs
			best_direction = signi(distance)
	return best_direction

func _service_stop(room) -> void:
	_log("cage service stop floor=%d direction=%d" % [room.y, direction])
	await open_doors()
	await _exit_passengers(room)
	await _board_passengers(room)
	await close_doors()

func _exit_passengers(room) -> void:
	var exiting: Array = []
	for npc in boarded_requests.keys():
		var request: ElevatorRideRequest = boarded_requests[npc]
		if is_instance_valid(request.to_room) and request.to_room == room:
			exiting.append(npc)
	if exiting.is_empty():
		return
	_log("cage exiting count=%d at floor=%d" % [exiting.size(), room.y])
	var remaining: Array = [exiting.size()]
	for npc in exiting:
		_finish_exit(npc, room, remaining)
	while remaining[0] > 0:
		await get_tree().process_frame

func _finish_exit(npc: NPC, room, remaining: Array) -> void:
	var request: ElevatorRideRequest = boarded_requests[npc]
	boarded_requests.erase(npc)
	if not is_instance_valid(npc):
		request.finished.emit()
		remaining[0] -= 1
		return
	npc.global_position = get_passenger_position(npc)
	npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	unboard(npc)
	_log("walk out npc=%s pos=%s" % [npc.name, str(room.get_exit_position())])
	await npc.Navigation.force_walk_to(room.get_exit_position(), WALK_SPEED)
	request.finished.emit()
	remaining[0] -= 1

func _board_passengers(room) -> void:
	if not controller.is_powered():
		return
	var boarding: Array = []
	for request in controller.pending_requests:
		if request.from_room == room and request.direction == direction:
			boarding.append(request)
	if boarding.is_empty():
		return
	_log("cage boarding count=%d at floor=%d" % [boarding.size(), room.y])
	for request in boarding:
		controller.pending_requests.erase(request)

	var remaining: Array = [boarding.size()]
	var next_slot: int = passengers.size()
	for request in boarding:
		_finish_board(request, room, next_slot, remaining)
		next_slot += 1
	while remaining[0] > 0:
		await get_tree().process_frame

func _finish_board(request: ElevatorRideRequest, room, slot: int, remaining: Array) -> void:
	var npc: NPC = request.npc
	if not is_instance_valid(npc):
		remaining[0] -= 1
		return
	room.leave_queue(npc, request.direction)
	_log("walk to boarding npc=%s pos=%s" % [npc.name, str(room.get_boarding_position())])
	await npc.Navigation.force_walk_to(room.get_boarding_position(), WALK_SPEED)
	_log("walk into cage npc=%s slot=%d" % [npc.name, slot])
	await npc.Navigation.force_walk_to(global_position + slot_offset(slot), WALK_SPEED)
	board(npc)
	npc.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT) # same as tables/gambling - keeps them behind the closed door
	boarded_requests[npc] = request
	remaining[0] -= 1

func move_to(target: Vector2, speed: float, ease_in: bool = true, ease_out: bool = true) -> void:
	_log("cage move start from=%s to=%s" % [str(global_position), str(target)])
	var distance := global_position.distance_to(target)
	if distance > 0.01:
		SoundPlayer.play_elevator_start(global_position)
		var tween := create_tween()
		if ease_in and ease_out:
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		elif ease_in:
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		elif ease_out:
			tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			tween.set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(self, "global_position", target, distance / speed)
		await tween.finished
		SoundPlayer.play_elevator_stop(target)
	global_position = target
	_log("cage move done at=%s" % str(global_position))

func board(npc: NPC) -> void:
	if npc in passengers:
		return
	var slot := _get_next_free_slot()
	passengers.append(npc)
	_passenger_slots[npc] = slot
	_passenger_offsets[npc] = slot_offset(slot)
	npc.global_position = global_position + _passenger_offsets[npc]
	_log("board npc=%s slot=%d passengers=%d" % [npc.name, slot, passengers.size()])

func cancel_request(request: ElevatorRideRequest) -> bool:
	if request == null:
		return false

	var boarded_npc: NPC = null
	for npc: NPC in boarded_requests.keys():
		if boarded_requests[npc] == request:
			boarded_npc = npc
			break

	if boarded_npc == null:
		return false

	boarded_requests.erase(boarded_npc)
	if is_instance_valid(boarded_npc):
		boarded_npc.global_position = get_passenger_position(boarded_npc)
		boarded_npc.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	unboard(boarded_npc)
	_log("cancel boarded request npc=%s passengers=%d" % [boarded_npc.name if is_instance_valid(boarded_npc) else "<invalid>", passengers.size()])
	return true

func unboard(npc: NPC) -> void:
	passengers.erase(npc)
	_passenger_offsets.erase(npc)
	_passenger_slots.erase(npc)
	_log("unboard npc=%s passengers=%d" % [npc.name, passengers.size()])

func get_passenger_position(npc: NPC = null) -> Vector2:
	if npc != null and _passenger_slots.has(npc):
		return global_position + slot_offset(_passenger_slots[npc])
	return global_position + slot_offset(_get_next_free_slot())

const LEFT_X := -8.0
const RIGHT_X := 8.0

func slot_offset(slot: int) -> Vector2:
	var t: float = fmod(slot * PI, 1.0) # PI's irrationality spreads slots out instead of clustering/repeating
	return Vector2(lerp(LEFT_X, RIGHT_X, t), 0.0)

func _get_next_free_slot() -> int:
	var used: Array = _passenger_slots.values()
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot

func open_doors() -> void:
	_log("doors opening")
	await _animate_frames(3, 1)
	_log("doors open")

func close_doors() -> void:
	_log("doors closing")
	await _animate_frames(0, -1)
	_log("doors closed")

var _animating := false # guards against two concurrent animations fighting over cab.frame and never converging

func _animate_frames(target: int, step: int) -> void:
	if _animating:
		_log("cage animate_frames BLOCKED - already animating, target=%d step=%d" % [target, step])
	while _animating:
		await get_tree().process_frame
	_animating = true
	while cab.frame != target:
		cab.frame += step
		await get_tree().create_timer(0.05).timeout
	_animating = false

const DEBUG_UP_COLOR := Color.CYAN
const DEBUG_DOWN_COLOR := Color.ORANGE

func debug_draw() -> void:
	var direction_color: Color = DEBUG_UP_COLOR if direction > 0 else (DEBUG_DOWN_COLOR if direction < 0 else Color.GRAY)
	DebugDraw2D.circle_filled(global_position, 5.0, 12, direction_color)
	for i in passengers.size():
		DebugDraw2D.circle_filled(global_position + Vector2(0.0, -9.0 - i * 4.0), 1.5, 6, direction_color)
