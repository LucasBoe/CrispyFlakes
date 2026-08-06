extends Node

const OUTDOOR_PENALTY := 90000.0        # ~300px bias toward indoor targets
const SPREAD_RADIUS := 100.0            # penalty radius around other cleaners' targets
const BED_OUTHOUSE_SCORE_DIVISOR := 3.0 # dirty beds/outhouses are 3x as attractive
const DRINK_SEARCH_RANGE := 99999.0

const DEBUG_RECT_SIZE := Vector2(14, 14)

var _dirty_beds: Array[RoomBed] = []
var _full_outhouses: Array[RoomOuthouse] = []
var _reserved_beds: Array[RoomBed] = []
var _reserved_outhouses: Array[RoomOuthouse] = []
var _cleaner_targets: Dictionary = {} # npc -> Vector2
var debug_enabled: bool = false

func _ready() -> void:
	Console.add_command("debug_cleaning", _console_toggle_debug, [], 0, "Toggles continuous score visualization for the selected worker (green=best, red=worst) and logging of every cleaned target (type + location).")

func _process(_delta: float) -> void:
	if not debug_enabled:
		return
	var selected = Global.UI.selection.target if Global.UI != null and Global.UI.selection != null else null
	if selected is NPCWorker:
		_draw_scores_for(selected)

func register_dirty_bed(bed: RoomBed) -> void:
	if not _dirty_beds.has(bed):
		_dirty_beds.append(bed)

func unregister_dirty_bed(bed: RoomBed) -> void:
	_dirty_beds.erase(bed)

func register_full_outhouse(outhouse: RoomOuthouse) -> void:
	if not _full_outhouses.has(outhouse):
		_full_outhouses.append(outhouse)

func unregister_full_outhouse(outhouse: RoomOuthouse) -> void:
	_full_outhouses.erase(outhouse)

func find_target_for(npc: NPC):
	var candidates := _gather_candidates(npc)
	if candidates.is_empty():
		return null

	candidates.sort_custom(func(a, b): return _score_candidate(a, npc) < _score_candidate(b, npc))
	return candidates[0]

## Returns [{ "target": candidate, "score": float }], best (lowest score) first.
func get_scored_candidates(npc: NPC) -> Array:
	var candidates := _gather_candidates(npc)
	var scored: Array = []
	for candidate in candidates:
		scored.append({"target": candidate, "score": _score_candidate(candidate, npc)})
	scored.sort_custom(func(a, b): return a.score < b.score)
	return scored

func _gather_candidates(npc: NPC) -> Array:
	_prune_invalid()

	var candidates: Array = []
	for bed in _dirty_beds:
		if not _reserved_beds.has(bed):
			candidates.append(bed)
	for outhouse in _full_outhouses:
		if not _reserved_outhouses.has(outhouse):
			candidates.append(outhouse)

	candidates.append_array(DirtHandler.get_all_in_range(npc.global_position, DRINK_SEARCH_RANGE))
	candidates.append_array(PuddleHandler.get_all_in_range(npc.global_position, DRINK_SEARCH_RANGE))

	var closest_drink: Item = LooseItemHandler.get_closest_to(npc.global_position, Enum.Items.DRINK)
	if closest_drink != null:
		candidates.append(closest_drink)

	return candidates

func get_target_position(target) -> Vector2:
	if target is RoomOuthouse or target is RoomBed:
		return target.get_center_floor_position()
	return target.global_position

func reserve_target(npc: NPC, target) -> void:
	_cleaner_targets[npc] = get_target_position(target)
	if target is RoomBed:
		if not _reserved_beds.has(target):
			_reserved_beds.append(target)
		target.worker = npc
	elif target is RoomOuthouse:
		if not _reserved_outhouses.has(target):
			_reserved_outhouses.append(target)
		target.worker = npc

func release_target(npc: NPC, target) -> void:
	if not is_instance_valid(target):
		return
	if target is RoomBed:
		_reserved_beds.erase(target)
		if target.worker == npc:
			target.worker = null
	elif target is RoomOuthouse:
		_reserved_outhouses.erase(target)
		if target.worker == npc:
			target.worker = null

func unregister_cleaner(npc: NPC) -> void:
	_cleaner_targets.erase(npc)

func _score_candidate(candidate, npc: NPC) -> float:
	var pos := get_target_position(candidate)
	var score := pos.distance_squared_to(npc.global_position)

	if candidate is RoomBed or candidate is RoomOuthouse:
		score /= BED_OUTHOUSE_SCORE_DIVISOR

	var room = Building.query.room_at_position(pos)
	if room == null or room.is_outside_room:
		score += OUTDOOR_PENALTY

	var spread_sq := SPREAD_RADIUS * SPREAD_RADIUS
	for other_npc: Node in _cleaner_targets:
		if other_npc == npc:
			continue
		var dist_sq := pos.distance_squared_to(_cleaner_targets[other_npc])
		if dist_sq < spread_sq:
			score += spread_sq - dist_sq

	return score

func log_cleaned(target, npc: NPC) -> void:
	if not debug_enabled or not is_instance_valid(target):
		return
	Console.print_line("[BroomCleaner] %s cleaned %s at %s" % [npc.name, _describe_target_type(target), get_target_position(target)], true)

func _describe_target_type(target) -> String:
	if target is RoomBed:
		return "Bed"
	if target is RoomOuthouse:
		return "Outhouse"
	if target is Polygon2D:
		return "Puddle"
	if target is Sprite2D:
		return "Dirt"
	if target is Item:
		return "Dropped Drink"
	return str(target)

func _console_toggle_debug() -> void:
	debug_enabled = not debug_enabled
	Console.print_line("Cleaning debug %s." % ("enabled" if debug_enabled else "disabled"))

func _draw_scores_for(npc: NPC) -> void:
	var scored := get_scored_candidates(npc)
	if scored.is_empty():
		return

	var min_score: float = scored[0].score
	var max_score: float = scored[-1].score
	var score_range := maxf(max_score - min_score, 0.001)

	for entry in scored:
		var t: float = (entry.score - min_score) / score_range
		var color := Color(t, 1.0 - t, 0.0, 0.7) # green = best, red = worst
		DebugDraw2D.rect_filled(get_target_position(entry.target), DEBUG_RECT_SIZE, color, 0.0)

func _prune_invalid() -> void:
	for i in range(_dirty_beds.size() - 1, -1, -1):
		if not is_instance_valid(_dirty_beds[i]):
			_dirty_beds.remove_at(i)
	for i in range(_full_outhouses.size() - 1, -1, -1):
		if not is_instance_valid(_full_outhouses[i]):
			_full_outhouses.remove_at(i)
	for i in range(_reserved_beds.size() - 1, -1, -1):
		if not is_instance_valid(_reserved_beds[i]):
			_reserved_beds.remove_at(i)
	for i in range(_reserved_outhouses.size() - 1, -1, -1):
		if not is_instance_valid(_reserved_outhouses[i]):
			_reserved_outhouses.remove_at(i)
