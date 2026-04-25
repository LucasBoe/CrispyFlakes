extends Node

const PanicBehaviourScript = preload("res://scripts/npc/behaviours/panic_behaviour.gd")
const GUEST_DRUNK_FIGHT_MIN_START_ENERGY := 0.35
const DEBUG_GUTLESS_PANIC := true

var active_fights: Array[Fight] = []
var _next_fight_debug_id := 1

# FIGHT CREATION

func _create_fight(position: Vector2) -> Fight:
	var room := _get_closest_indoor_room(position)
	var fight = Fight.new()
	fight.debug_id = _next_fight_debug_id
	_next_fight_debug_id += 1
	active_fights.append(fight)
	fight.room = room
	print("[FightHandler] create fight #%d room=%s position=%s" % [
		fight.debug_id,
		room.name if room != null else "<none>",
		position,
	])
	return fight

func get_or_create_fight(npc: NPC) -> Fight:
	var room := _get_closest_indoor_room(npc.global_position)
	var fight: Fight = null
	if room != null:
		fight = get_fight_for_floor(room.y)
	if fight == null:
		fight = _create_fight(npc.global_position)
	fight.make_join_fight(npc)
	return fight

func create_or_join_drunk_fight(guest: NPCGuest) -> void:
	if not _is_in_active_fight(guest):
		guest.energy = maxf(guest.energy, GUEST_DRUNK_FIGHT_MIN_START_ENERGY)
	get_or_create_fight(guest)

func create_rob_fight(guest: NPCGuest, room: RoomBase) -> void:
	var existing := get_fight_for_room(room)
	if existing != null:
		existing.make_join_fight(guest)
		return
	var fight := _create_fight(room.get_center_floor_position())
	fight.fight_type = Fight.FightType.ROBBERY
	fight.make_join_fight(guest)

func create_defense_fight(guest: NPCGuest, worker: NPCWorker) -> void:
	var fight := _create_fight(guest.global_position)
	fight.fight_type = Fight.FightType.ARREST
	fight.make_join_fight(guest)
	fight.make_join_fight(worker)

func get_fight_for_room(room: RoomBase) -> Fight:
	for fight: Fight in active_fights:
		if fight.room == room:
			return fight
	return null

func get_fight_for_floor(floor_y: int) -> Fight:
	for fight: Fight in active_fights:
		if fight.room != null and fight.room.y == floor_y:
			return fight
	return null

# FIGHT PROGRESSION

func _process(_delta: float) -> void:
	for fight: Fight in active_fights.duplicate():
		if not active_fights.has(fight):
			continue

		_try_panic_gutless_near_fight(fight)

		if fight.has_started:
			fight.handle_fight()
			continue

		if fight.get_active_participants().size() >= 2:
			fight.start_fight()
			continue

		if fight.fight_type != Fight.FightType.ARREST and fight.participants.size() <= 1:
			if not ConflictResponseHandler.try_join_brawl(fight) and not _try_attract_brawlers(fight):
				end_fight(fight)

# FIGHT ENDING

func end_fight(fight: Fight) -> void:
	if fight == null or not active_fights.has(fight):
		return
	print("[FightHandler] end fight #%d state=%s result=%s participants=%s" % [
		fight.debug_id,
		Fight.State.keys()[fight.state],
		Fight.Result.keys()[fight.result],
		fight._participants_debug(),
	])
	if fight.state != Fight.State.OVER:
		fight.state = Fight.State.OVER
		fight.result = Fight.Result.NO_CONTEST
	fight.is_over = true
	_release_panicking_guests(fight)
	fight.clear_health_bars()
	RoomHighlighter.dispose(fight.highlight)
	fight.highlight = null
	active_fights.erase(fight)

func _release_panicking_guests(fight: Fight) -> void:
	if Global.NPCSpawner == null:
		return

	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not is_instance_valid(guest) or guest.Behaviour == null:
			continue

		var current := guest.Behaviour.behaviour_instance
		if current == null or current.get_script() != PanicBehaviourScript:
			continue

		if current.data == null or current.data.extra.get("fight", null) != fight:
			continue

		guest.Behaviour.clear_behaviour()

func _try_attract_brawlers(fight: Fight) -> bool:
	if Global.NPCSpawner == null or fight.room == null:
		return false
	var attracted := false
	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not is_instance_valid(guest) or fight.has_participant(guest):
			continue
		if not is_within_fight_detection_range(get_fight_position(fight), guest.global_position):
			continue
		if randf() < guest.Traits.get_voluntary_fight_chance(guest.Needs.drunkenness.strength):
			create_or_join_drunk_fight(guest)
			attracted = true
	return attracted

func _try_panic_gutless_near_fight(fight: Fight) -> void:
	if Global.NPCSpawner == null or not is_started_active_fight(fight):
		return

	for guest: NPCGuest in Global.NPCSpawner.guests:
		_try_panic_gutless_npc(guest, fight)
	for worker: NPCWorker in Global.NPCSpawner.workers:
		_try_panic_gutless_npc(worker, fight)

func _try_panic_gutless_npc(npc: NPC, fight: Fight) -> bool:
	if not _can_panic_from_fight(npc, fight):
		return false

	_debug_gutless_panic(npc, fight, "panic start")
	var panic_data := BehaviourSaveData.new(PanicBehaviourScript)
	panic_data.extra["fight"] = fight
	panic_data.extra["threat_room"] = fight.room
	panic_data.extra["threat_position"] = get_fight_position(fight)
	npc.Behaviour.set_behaviour(PanicBehaviourScript, panic_data)
	return true

func _can_panic_from_fight(npc: NPC, fight: Fight) -> bool:
	if not is_instance_valid(npc) or npc.Traits == null:
		return false
	if not npc.Traits.refuses_voluntary_fights():
		return false
	if fight.has_participant(npc):
		_debug_gutless_panic(npc, fight, "skip already in fight")
		return false
	var fight_position := get_fight_position(fight)
	var in_range := is_within_fight_detection_range(fight_position, npc.global_position)
	_debug_gutless_panic(npc, fight, "range check", fight_position, npc.global_position, in_range)
	if not in_range:
		return false
	if npc is NPCWorker and NPCWorker.picked_up_npc == npc:
		_debug_gutless_panic(npc, fight, "skip picked up")
		return false
	if npc.Behaviour == null:
		_debug_gutless_panic(npc, fight, "skip no behaviour module")
		return false

	var current = npc.Behaviour.behaviour_instance
	if current != null and current.get_script() == PanicBehaviourScript:
		_debug_gutless_panic(npc, fight, "skip already panicking")
		return false
	if current is KnockedOutBehaviour or current is ArrestedBehaviour or current is FollowSheriffBehaviour:
		_debug_gutless_panic(npc, fight, "skip blocked behaviour %s" % _behaviour_name(current))
		return false
	return true

func is_within_fight_detection_range(a: Vector2, b: Vector2) -> bool:
	var diff := b - a
	return abs(diff.x) < 96.0 and abs(diff.y) < 16.0

func is_fight_near_room(room: RoomBase) -> bool:
	if not is_instance_valid(room):
		return false
	for fight: Fight in active_fights:
		if not is_started_active_fight(fight):
			continue
		if fight.room == room:
			_debug_room_fight_range(room, fight, "same room", true)
			return true
		var fight_position: Vector2 = get_fight_position(fight)
		var room_position: Vector2 = room.get_center_floor_position()
		var in_range: bool = is_within_fight_detection_range(fight_position, room_position)
		_debug_room_fight_range(room, fight, "range check", in_range, fight_position, room_position)
		if in_range:
			return true
	return false

func get_fight_position(fight: Fight) -> Vector2:
	if fight == null:
		return Vector2.INF
	if fight.room != null:
		return fight.room.get_center_floor_position()
	for participant in fight.participants:
		var npc := participant as NPC
		if is_instance_valid(npc):
			return npc.global_position
	return Vector2.INF

func is_started_active_fight(fight: Fight) -> bool:
	return fight != null and fight.has_started and not fight.is_over and active_fights.has(fight)

func _debug_gutless_panic(npc: NPC, fight: Fight, reason: String, fight_position: Vector2 = Vector2.INF, npc_position: Vector2 = Vector2.INF, in_range := false) -> void:
	if not DEBUG_GUTLESS_PANIC:
		return
	var current = npc.Behaviour.behaviour_instance if npc != null and npc.Behaviour != null else null
	var details := ""
	if fight_position != Vector2.INF or npc_position != Vector2.INF:
		var diff := npc_position - fight_position
		details = " fight_pos=%s npc_pos=%s diff=%s in_range=%s" % [fight_position, npc_position, diff, in_range]
	print("[GutlessPanic] npc=%s type=%s behaviour=%s fight=%s room=%s reason=%s%s" % [
		npc.name if is_instance_valid(npc) else "<invalid>",
		npc.get_script().get_global_name() if is_instance_valid(npc) and npc.get_script() != null else "<none>",
		_behaviour_name(current),
		fight.debug_label() if fight != null else "<none>",
		fight.room.name if fight != null and fight.room != null else "<none>",
		reason,
		details,
	])

func _debug_room_fight_range(room: RoomBase, fight: Fight, reason: String, in_range: bool, fight_position: Vector2 = Vector2.INF, room_position: Vector2 = Vector2.INF) -> void:
	if not DEBUG_GUTLESS_PANIC:
		return
	var details := ""
	if fight_position != Vector2.INF or room_position != Vector2.INF:
		var diff := room_position - fight_position
		details = " fight_pos=%s room_pos=%s diff=%s" % [fight_position, room_position, diff]
	print("[GutlessPanic] room=%s fight=%s reason=%s in_range=%s%s" % [
		room.name if is_instance_valid(room) else "<invalid>",
		fight.debug_label() if fight != null else "<none>",
		reason,
		in_range,
		details,
	])

func _behaviour_name(behaviour) -> String:
	if behaviour == null or behaviour.get_script() == null:
		return "<none>"
	return behaviour.get_script().resource_path.get_file()

# HELPERS

func _is_in_active_fight(npc: NPC) -> bool:
	for fight: Fight in active_fights:
		if fight.has_participant(npc):
			return true
	return false

func _get_closest_indoor_room(position: Vector2) -> RoomBase:
	var closest: RoomBase = null
	var closest_dist := INF
	for floor_rooms: Dictionary in Building.floors.values():
		for room: RoomBase in floor_rooms.values():
			if room.is_outside_room:
				continue
			# TODO: Replace this proximity fallback with room-index based fight placement.
			var d := room.global_position.distance_to(position)
			if d < closest_dist:
				closest_dist = d
				closest = room
	return closest

func _get_actor_room(actor: Node2D) -> RoomBase:
	if actor == null or not is_instance_valid(actor):
		return null

	var exact := Building.query.room_at_floor_position(actor.global_position) as RoomBase
	if exact != null:
		return exact
	return Building.query.closest_on_current_floor(RoomBase, actor.global_position) as RoomBase
