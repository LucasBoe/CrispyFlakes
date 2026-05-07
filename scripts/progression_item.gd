class_name ProgressionItem
extends Resource

enum ProgressionFlag {
	NONE,
	BIG_TABLES,
	BIG_BREWER,
	STABLES,
}

@export var sprite: Texture2D
@export var display_name: String
@export_multiline var description: String = ""

## Optional: global flags set to true when this group becomes available
@export var unlocks_flags: Array[ProgressionFlag] = []

## Legacy single-room field kept for old resources; new group logic uses unlocks_rooms.
@export var unlocks_room: RoomData

## Legacy single-infrastructure field kept for old resources; new group logic uses unlocks_infrastructure_list.
@export var unlocks_infrastructure: InfrastructureData

## Optional: group contents that become buildable when this item is unlocked
@export var unlocks_rooms: Array[RoomData] = []
@export var unlocks_infrastructure_list: Array[InfrastructureData] = []

## Optional: main parent item used for the visual tree edge and as a prerequisite
@export var depends_on: ProgressionItem

## Optional: additional prerequisite items that must be completed before this one becomes available
@export var required_items: Array[ProgressionItem] = []

func get_unlocked_rooms() -> Array[RoomData]:
	var rooms: Array[RoomData] = []
	if unlocks_room != null:
		rooms.append(unlocks_room)
	for room in unlocks_rooms:
		if room != null and not rooms.has(room):
			rooms.append(room)
	return rooms

func get_unlocked_infrastructure() -> Array[InfrastructureData]:
	var infrastructure_items: Array[InfrastructureData] = []
	if unlocks_infrastructure != null:
		infrastructure_items.append(unlocks_infrastructure)
	for data in unlocks_infrastructure_list:
		if data != null and not infrastructure_items.has(data):
			infrastructure_items.append(data)
	return infrastructure_items

func get_required_items() -> Array[ProgressionItem]:
	var items: Array[ProgressionItem] = []
	if depends_on != null:
		items.append(depends_on)
	for item in required_items:
		if item != null and not items.has(item):
			items.append(item)
	return items

func get_content_count() -> int:
	return get_unlocked_rooms().size() + get_unlocked_infrastructure().size()

func has_content() -> bool:
	return get_content_count() > 0
