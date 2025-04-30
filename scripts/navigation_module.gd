extends Node2D


var currentRoomIndex
var targetFinal
var targetPath = []

@onready var animationModule : AnimationModule = $"../Visuals"

const MOVE_SPEED = 24

func _process(delta):
	currentRoomIndex = Global.building.round_room_index_from_global_position(global_position + Vector2(0,-1))
	
	animationModule.direction = Vector2.ZERO
	
	#debug draw nav path
	var previous = global_position;
	for p in targetPath:
		DebugDraw2D.line(previous, p)
		previous = p
	
	#refresh target path
	if not targetFinal:
		targetFinal = pick_next_target()
		refresh_target_path()
	
	#check reached target
	if global_position.distance_to(targetPath[0]) < 1:
		targetPath.remove_at(0)
		if targetPath.is_empty():
			targetFinal = 0
			return
	
	if len(targetPath) == 0:
		return
	
	#move towards next target position
	var prnt = get_parent()
	animationModule.direction = targetPath[0] - prnt.global_position
	prnt.global_position = prnt.global_position.move_toward(targetPath[0], delta * MOVE_SPEED)
	
func pick_next_target():
	var floor = Util.get_random_element(Global.building.floors)
	return Util.get_random_element(floor)
	
func refresh_target_path():
	
	targetPath.clear()
	
	var targetRoomIndex = Global.building.round_room_index_from_global_position(targetFinal.global_position)
	var last_position = global_position
	var currentY = currentRoomIndex.y
	var targetY = targetRoomIndex.y
	
	#navigate to target floor
	if targetY != currentY:
		var goDownwards = targetRoomIndex.y < currentRoomIndex.y
		var multiplier = 1 if goDownwards else -1
		
		for i in range(currentRoomIndex.y, targetRoomIndex.y, -1 * multiplier):
			var stairs = Global.building.get_closest_room_of_type(RoomStairs, last_position, i) as RoomStairs
			targetPath.append(stairs.global_position + Vector2(8  if goDownwards else 36, 0 * multiplier))
			targetPath.append(stairs.global_position + Vector2(28 if goDownwards else 36, 24 * multiplier))
			targetPath.append(stairs.global_position + Vector2(36 if goDownwards else 28, 24 * multiplier))
			targetPath.append(stairs.global_position + Vector2(36 if goDownwards else 8 , 48 * multiplier))
			last_position = stairs.global_position
				
	#move to target location
	targetPath.append(targetFinal.global_position + Vector2(24,0));
