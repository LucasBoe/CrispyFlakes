extends Node2D


var currentRoomIndex
var targetFinal
var targetPath = []


func _process(delta):
	currentRoomIndex = Global.building.round_room_index_from_global_position(global_position + Vector2(0,-1))
	
	var previous = global_position;
	
	for p in targetPath:
		DebugDraw2D.line(previous, p)
		previous = p
	
	
	if not targetFinal:
		targetFinal = pick_next_target()
		refresh_target_path()
	
	if global_position.distance_to(targetPath[0]) < 1:
		targetPath.remove_at(0)
		if targetPath.is_empty():
			targetFinal = 0
			return
	
	if len(targetPath) == 0:
		return
	
	#print(str("move towards", targetPath[0]))
	var prnt = get_parent()
	prnt.global_position = prnt.global_position.move_toward(targetPath[0], delta * 24)
	
func pick_next_target():
	var floor = Util.get_random_element(Global.building.floors)
	return Util.get_random_element(floor)
	
func refresh_target_path():
	
	targetPath.clear()
	var targetRoomIndex = Global.building.round_room_index_from_global_position(targetFinal.global_position)
	var pos = global_position
	
	var currentY = currentRoomIndex.y
	var targetY = targetRoomIndex.y
	
	
	if targetY != currentY:
		print(str("currentY", currentY, "is not targetY", targetY))
		var goDownwards = targetRoomIndex.y < currentRoomIndex.y
		if goDownwards:
			var rng = range(currentRoomIndex.y, targetRoomIndex.y, -1)
			for i in rng:
				var stairs = Global.building.get_closest_room_of_type(RoomStairs, pos, i) as RoomStairs
				targetPath.append(stairs.global_position + Vector2(12,0))
				targetPath.append(stairs.global_position + Vector2(36,24))
				targetPath.append(stairs.global_position + Vector2(36,48))
				pos = stairs.global_position
		else:
			for i in range(currentRoomIndex.y, targetRoomIndex.y):
				var stairs = Global.building.get_closest_room_of_type(RoomStairs, pos, i) as RoomStairs
				targetPath.append(stairs.global_position + Vector2(36,0))
				targetPath.append(stairs.global_position + Vector2(36,-24))
				targetPath.append(stairs.global_position + Vector2(12,-48))
	else:
		print(str("currentY", currentY, "is targetY", targetY))
				
	targetPath.append(targetFinal.global_position + Vector2(24,0));
