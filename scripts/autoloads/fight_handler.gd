extends Node

const GUEST_DRUNK_FIGHT_MIN_START_ENERGY := 0.35

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
	var fight := _create_fight(room.get_center_position())
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
	fight.clear_health_bars()
	RoomHighlighter.dispose(fight.highlight)
	fight.highlight = null
	active_fights.erase(fight)

func _try_attract_brawlers(fight: Fight) -> bool:
	if Global.NPCSpawner == null or fight.room == null:
		return false
	var attracted := false
	for guest: NPCGuest in Global.NPCSpawner.guests:
		if not is_instance_valid(guest) or fight.has_participant(guest):
			continue
		if not is_within_fight_detection_range(fight.room.get_center_position(), guest.global_position):
			continue
		if randf() < guest.Traits.get_voluntary_fight_chance(guest.Needs.drunkenness.strength):
			create_or_join_drunk_fight(guest)
			attracted = true
	return attracted

func is_within_fight_detection_range(a: Vector2, b: Vector2) -> bool:
	var diff := b - a
	return abs(diff.x) < 96.0 and abs(diff.y) < 16.0

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

	var exact := Building.query.room_at_position(actor.global_position) as RoomBase
	if exact != null:
		return exact
	return Building.query.closest_room_of_type(RoomBase, actor.global_position) as RoomBase
