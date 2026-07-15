extends Behaviour
class_name PanicBehaviour

var _notification = null
var _threat_position: Vector2 = Vector2.ZERO
var _threat_room: RoomBase = null

func start_loop() -> void:
	_narrative = ["Panicking!", "Getting away!", "Nope nope nope!"].pick_random()
	_notification = UiNotifications.create_notification_dynamic("!", npc, Vector2(0, -32), null, Color.ORANGE, INF)
	_read_data()
	print("[GutlessPanic] behaviour start npc=%s threat_room=%s threat_pos=%s" % [
		npc.name,
		_threat_room.name if _threat_room != null else "<none>",
		_threat_position,
	])

func loop() -> void:
	if npc.Item.current_item != null:
		npc.Item.drop_current()

	_move_to_escape_room()

	if stopped:
		return

	_narrative = _waiting_narrative()
	while not stopped:
		await end_of_frame()

func stop_loop() -> BehaviourSaveData:
	UiNotifications.try_kill(_notification)
	return BehaviourSaveData.new(get_script())

func _read_data() -> void:
	if data == null:
		_threat_position = npc.global_position
		return
	_threat_room = data.extra.get("threat_room", null) as RoomBase
	_threat_position = data.extra.get("threat_position", npc.global_position)

func register_threat(threat_room: RoomBase, threat_position: Vector2) -> void:
	_threat_room = threat_room
	_threat_position = threat_position
	_move_to_escape_room()

func _move_to_escape_room() -> void:
	var escape_room := _find_escape_room()
	if escape_room != null:
		print("[GutlessPanic] npc=%s fleeing_to=%s pos=%s" % [npc.name, escape_room.name, escape_room.get_center_floor_position()])
		npc.Navigation.set_target(escape_room.get_random_floor_position(), -1)
	else:
		print("[GutlessPanic] npc=%s no_escape_room" % npc.name)

func _find_escape_room() -> RoomBase:
	var reachable := npc.Navigation.get_reachable_rooms()
	var best_room: RoomBase = null
	var best_distance := -INF
	print("[GutlessPanic] npc=%s reachable_rooms=%d" % [npc.name, reachable.size()])

	for room: RoomBase in reachable:
		if room == null or room == _threat_room:
			continue
		var distance: float = room.get_center_floor_position().distance_squared_to(_threat_position)
		if _is_room_near_any_threat(room):
			print("[GutlessPanic] npc=%s reject_escape_room=%s near_threat=true" % [npc.name, room.name])
			continue
		if distance > best_distance:
			best_distance = distance
			best_room = room

	if best_room != null:
		return best_room

	for room: RoomBase in reachable:
		if room == null or room == _threat_room:
			continue
		var distance: float = room.get_center_floor_position().distance_squared_to(_threat_position)
		if distance > best_distance:
			best_distance = distance
			best_room = room
	return best_room

func _is_room_near_any_threat(room: RoomBase) -> bool:
	for fight: Fight in FightHandler.active_fights:
		if not FightHandler.is_started_active_fight(fight):
			continue
		if fight.room == room:
			return true
		var fight_position := FightHandler.get_fight_position(fight)
		if FightHandler.is_within_fight_detection_range(fight_position, room.get_center_floor_position()):
			return true
	if FireHandler.is_fire_near_room(room):
		return true
	return false

func _waiting_narrative() -> String:
	return ["Hiding out...", "Keeping clear...", "Waiting it out..."].pick_random()
