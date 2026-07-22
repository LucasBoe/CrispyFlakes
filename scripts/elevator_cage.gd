extends Node2D
class_name ElevatorCage

@onready var cab: Sprite2D = $Cab

var passengers: Array[NPC] = []
var _passenger_offsets: Dictionary = {}

func _ready() -> void:
	close_doors()

func _process(_delta: float) -> void:
	for npc in passengers:
		if is_instance_valid(npc):
			npc.global_position = global_position + _passenger_offsets[npc]

func move_to(target: Vector2, speed: float) -> void:
	ElevatorHandler.debug_log("cage move start from=%s to=%s" % [str(global_position), str(target)])
	while global_position.distance_to(target) > 1.0:
		global_position = global_position.move_toward(target, get_process_delta_time() * speed)
		await get_tree().process_frame
	global_position = target
	ElevatorHandler.debug_log("cage move done at=%s" % str(global_position))

func board(npc: NPC, offset := Vector2.ZERO) -> void:
	if npc not in passengers:
		passengers.append(npc)
	_passenger_offsets[npc] = offset
	npc.global_position = global_position + offset
	ElevatorHandler.debug_log("board npc=%s passengers=%d" % [npc.name, passengers.size()])

func unboard(npc: NPC) -> void:
	passengers.erase(npc)
	_passenger_offsets.erase(npc)
	ElevatorHandler.debug_log("unboard npc=%s passengers=%d" % [npc.name, passengers.size()])

func get_passenger_position(slot := 0) -> Vector2:
	return global_position + Vector2(slot * 8.0 - 4.0, 0.0)

func open_doors() -> void:
	ElevatorHandler.debug_log("doors opening")
	await _animate_frames(3, 1)
	ElevatorHandler.debug_log("doors open")

func close_doors() -> void:
	ElevatorHandler.debug_log("doors closing")
	await _animate_frames(0, -1)
	ElevatorHandler.debug_log("doors closed")

func _animate_frames(target: int, step: int) -> void:
	while cab.frame != target:
		cab.frame += step
		await get_tree().create_timer(0.05).timeout
