extends RoomBase
class_name RoomSickWard

const MAX_BEDS := 2
const BED_POSITIONS: Array[Vector2] = [Vector2(32, -8), Vector2(84, -8)]

var treat_guests := true
var treat_workers := true
var current_guests: Array[NPCGuest] = []

func init_room(_x: int, _y: int) -> void:
	super.init_room(_x, _y)

func is_full() -> bool:
	return current_guests.size() >= MAX_BEDS

func occupy(guest: NPCGuest) -> void:
	if not current_guests.has(guest):
		current_guests.append(guest)

func release(guest: NPCGuest) -> void:
	current_guests.erase(guest)

func get_bed_position_for(guest: NPCGuest) -> Vector2:
	var idx: int = current_guests.find(guest)
	if idx < 0 or idx >= BED_POSITIONS.size():
		return get_center_floor_position()
	return global_position + BED_POSITIONS[idx]

func get_random_floor_position() -> Vector2:
	return global_position + Vector2(randi_range(4, 92), 0)

func get_center_floor_position() -> Vector2:
	return global_position + Vector2(48, 0)

func accepts_patient(patient: NPC) -> bool:
	if patient == null or not is_instance_valid(patient):
		return false
	if patient is NPCGuest:
		return treat_guests
	if patient is NPCWorker:
		return treat_workers
	return false
