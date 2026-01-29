extends Node2D

class_name NavigationModule

var npc : NPC
var currentRoomIndex
var targetPath = []
var targetFinal

var has_target = false
var is_moving = false

const MOVE_SPEED = 32

signal target_reached_signal

func _ready():
	npc = get_parent() as NPC
	if npc:
		pass
		
	npc.Navigation = self
	
func _process(delta):
	currentRoomIndex = Global.Building.round_room_index_from_global_position(global_position + Vector2(0,-1))
	
	if not has_target:
		return
	
	npc.Animator.direction = Vector2.ZERO
	
	#debug draw nav path
	var previous = global_position;
	for p in targetPath:
		DebugDraw2D.line(previous, p)
		previous = p
	
	#check reached target
	if global_position.distance_to(targetPath[0]) < 1:
		targetPath.remove_at(0)
		if targetPath.is_empty():
			stop_navigation()
			target_reached_signal.emit()
			return
	
	if len(targetPath) == 0:
		return
	
	#move towards next target position
	npc.Animator.direction = targetPath[0] - npc.global_position
	npc.global_position = npc.global_position.move_toward(targetPath[0], delta * MOVE_SPEED)

func stop_navigation():
	targetFinal = null
	has_target = false
	is_moving = false

func set_target(target):
	targetFinal = target
	refresh_target_path()
	is_moving = true
	has_target = true

func get_random_target():
	var floor = Util.get_random_element(Global.Building.floors)
	return Util.get_random_element(floor)
	
func refresh_target_path():
	
	targetPath.clear()
	
	if targetFinal is Node2D:
		targetFinal = targetFinal.global_position + Vector2(24,0)
	
	var targetRoomIndex = Global.Building.round_room_index_from_global_position(targetFinal)
	var last_position = global_position
	var currentY = currentRoomIndex.y
	var targetY = targetRoomIndex.y
	
	#navigate to target floor
	if targetY != currentY:
		var goDownwards = targetRoomIndex.y < currentRoomIndex.y
		var multiplier = 1 if goDownwards else -1
		
		for i in range(currentRoomIndex.y, targetRoomIndex.y, -1 * multiplier):
			var stairs = Global.Building.get_closest_room_of_type_on_floor(RoomStairs, last_position, i) as RoomStairs
			targetPath.append(stairs.global_position + Vector2(8  if goDownwards else 36, 0 * multiplier))
			targetPath.append(stairs.global_position + Vector2(28 if goDownwards else 36, 24 * multiplier))
			targetPath.append(stairs.global_position + Vector2(36 if goDownwards else 28, 24 * multiplier))
			targetPath.append(stairs.global_position + Vector2(36 if goDownwards else 8 , 48 * multiplier))
			last_position = stairs.global_position
				
	#move to target location
	targetPath.append(targetFinal);
