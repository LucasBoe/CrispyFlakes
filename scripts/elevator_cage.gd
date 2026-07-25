extends Node2D
class_name ElevatorCage

@onready var cab: Sprite2D = $Cab

var passengers: Array[NPC] = []
var _passenger_offsets: Dictionary = {}
var _passenger_slots: Dictionary = {}

func _ready() -> void:
	cab.frame = 0 # set directly, not animated - see _animate_frames' concurrency guard below for why

func _process(_delta: float) -> void:
	for npc in passengers:
		if is_instance_valid(npc):
			npc.global_position = global_position + _passenger_offsets[npc]

func move_to(target: Vector2, speed: float, ease_in: bool = true, ease_out: bool = true) -> void:
	ElevatorHandler.debug_log("cage move start from=%s to=%s" % [str(global_position), str(target)])
	var distance := global_position.distance_to(target)
	if distance > 0.01:
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
	global_position = target
	ElevatorHandler.debug_log("cage move done at=%s" % str(global_position))

func board(npc: NPC) -> void:
	if npc in passengers:
		return
	var slot := _get_next_free_slot()
	passengers.append(npc)
	_passenger_slots[npc] = slot
	_passenger_offsets[npc] = slot_offset(slot)
	npc.global_position = global_position + _passenger_offsets[npc]
	ElevatorHandler.debug_log("board npc=%s slot=%d passengers=%d" % [npc.name, slot, passengers.size()])

func unboard(npc: NPC) -> void:
	passengers.erase(npc)
	_passenger_offsets.erase(npc)
	_passenger_slots.erase(npc)
	ElevatorHandler.debug_log("unboard npc=%s passengers=%d" % [npc.name, passengers.size()])

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
	ElevatorHandler.debug_log("doors opening")
	await _animate_frames(3, 1)
	ElevatorHandler.debug_log("doors open")

func close_doors() -> void:
	ElevatorHandler.debug_log("doors closing")
	await _animate_frames(0, -1)
	ElevatorHandler.debug_log("doors closed")

var _animating := false # guards against two concurrent animations fighting over cab.frame and never converging

func _animate_frames(target: int, step: int) -> void:
	if _animating:
		ElevatorHandler.debug_log("cage animate_frames BLOCKED - already animating, target=%d step=%d" % [target, step])
	while _animating:
		await get_tree().process_frame
	_animating = true
	while cab.frame != target:
		cab.frame += step
		await get_tree().create_timer(0.05).timeout
	_animating = false
