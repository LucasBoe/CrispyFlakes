extends RoomBase
class_name RoomBed

const SLEEP_DURATION := 60.0
const SLEEP_PRICE := 14

const BED_EMPTY := preload("res://assets/sprites/bed_empty_back.png")
const BED_EMPTY_DIRTY := preload("res://assets/sprites/bed_empty_back_dirty.png")
const BED_FULL := preload("res://assets/sprites/bed_full_back.png")

var current_guests: Array[NPCGuest] = []
var _bed_occupants: Dictionary = {}  # NPCGuest -> bed index
var _dirty_beds: Array[int] = []     # bed indices that need cleaning
var _active_beds: Array[Sprite2D] = []

# keep needs_cleaning as a computed property for the cleaner job
var needs_cleaning: bool:
	get: return not _dirty_beds.is_empty()

func init_room(_x: int, _y: int):
	associated_job = Enum.Jobs.BED_CLEANER
	super.init_room(_x, _y)
	if current_module == null:
		_set_active_beds_from_children(self)

func get_job_capacity(job = null) -> int:
	return get_associated_job_capacity(job)

func _on_module_bought(module) -> void:
	if module.bought:
		_set_active_module(module)

func _set_active_module(module) -> void:
	current_module = module
	_set_active_beds_from_children(module)

func _set_active_beds_from_children(parent: Node) -> void:
	_active_beds.clear()
	current_guests.clear()
	_bed_occupants.clear()
	_dirty_beds.clear()
	for child in parent.get_children():
		if _is_bed_sprite(child):
			_active_beds.append(child as Sprite2D)
	_refresh_visual()

func _is_bed_sprite(node: Node) -> bool:
	return node is Sprite2D and node.has_node("Bed_Front")

func is_used_by_other_then(npc: NPC) -> bool:
	if _active_beds.is_empty():
		return false
	var others := current_guests.filter(func(g): return g != npc)
	return others.size() >= _active_beds.size()

func is_available_for(npc: NPC) -> bool:
	# any bed slot that is neither occupied nor dirty
	for i in _active_beds.size():
		var occupied := false
		for g in _bed_occupants:
			if _bed_occupants[g] == i:
				occupied = true
				break
		if not occupied and not _dirty_beds.has(i):
			return true
	return false

func get_total_bed_count() -> int:
	return _active_beds.size()

func get_occupied_bed_count() -> int:
	return current_guests.size()

func occupy(guest: NPCGuest):
	for i in _active_beds.size():
		var occupied := false
		for g in _bed_occupants:
			if _bed_occupants[g] == i:
				occupied = true
				break
		if not occupied and not _dirty_beds.has(i):
			_bed_occupants[guest] = i
			current_guests.append(guest)
			_refresh_visual()
			return

func get_random_floor_position():
	var room_width := data.width if data != null else 1
	return global_position + Vector2(randi_range(4, room_width * 48 - 4), 0)

func get_center_position():
	var room_width := data.width if data != null else 1
	return global_position + Vector2(room_width * 24, -24)

func get_center_floor_position():
	var room_width := data.width if data != null else 1
	return global_position + Vector2(room_width * 24, 0)

func get_sleep_position():
	return get_center_floor_position() + Vector2(10, -6)

func get_sleep_position_for(guest: NPCGuest) -> Vector2:
	if not _bed_occupants.has(guest) or _active_beds.is_empty():
		return get_sleep_position()
	var idx: int = _bed_occupants[guest]
	if idx >= _active_beds.size():
		return get_sleep_position()
	return _active_beds[idx].global_position + Vector2(10, 2)

func release(guest: NPCGuest):
	if guest not in current_guests:
		return
	var idx: int = _bed_occupants[guest]
	_bed_occupants.erase(guest)
	current_guests.erase(guest)
	_dirty_beds.append(idx)
	_refresh_visual()

func clean_bed():
	if _dirty_beds.is_empty():
		return
	_dirty_beds.remove_at(0)
	_refresh_visual()

func get_sleep_price() -> int:
	return SLEEP_PRICE

func _refresh_visual():
	for i in _active_beds.size():
		var bed_sprite := _active_beds[i]
		var front := bed_sprite.get_node_or_null("Bed_Front") as Sprite2D

		var occupant: NPCGuest = null
		for guest in _bed_occupants:
			if _bed_occupants[guest] == i:
				occupant = guest
				break

		if occupant != null:
			bed_sprite.texture = BED_FULL
		elif _dirty_beds.has(i):
			bed_sprite.texture = BED_EMPTY_DIRTY
		else:
			bed_sprite.texture = BED_EMPTY

		bed_sprite.modulate = Color.WHITE
		if front:
			front.visible = occupant != null
