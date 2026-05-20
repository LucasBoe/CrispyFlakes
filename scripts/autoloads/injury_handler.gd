extends Node

const NEED_TREATMENT_BEHAVIOUR := preload("res://scripts/npc/behaviours/need_treatment_behaviour.gd")
const NEED_BARBER_SURGEON_TREATMENT_BEHAVIOUR := preload("res://scripts/npc/behaviours/need_barber_surgeon_treatment_behaviour.gd")
const BARBER_SURGEON_BEHAVIOUR := preload("res://scripts/npc/behaviours/barber_surgeon_behaviour.gd")

signal npc_injured(npc: NPC)
signal npc_recovered(npc: NPC)
signal guest_injured(guest: NPCGuest)
signal guest_recovered(guest: NPCGuest)

const UNTREATED_INJURY_SATISFACTION_LOSS := 0.05
const UNTREATED_INJURY_TICK_SECONDS := 20.0
const GOOD_TREATMENT_THRESHOLD := 0.6

var _injured: Array[NPC] = []
var _next_guest_penalty_time: Dictionary = {}
var _recovery_payment_sources: Dictionary = {}

func on_npc_injured(npc: NPC) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	if npc.Status != null:
		npc.Status.clear_status(Enum.NpcStatus.WELL_TREATED)
		npc.Status.clear_status(Enum.NpcStatus.BADLY_TREATED)
	_recovery_payment_sources.erase(npc)
	if not _injured.has(npc):
		_injured.append(npc)
	var guest := npc as NPCGuest
	if guest != null:
		_next_guest_penalty_time[guest] = Global.time_now + UNTREATED_INJURY_TICK_SECONDS
		guest_injured.emit(guest)
	npc_injured.emit(npc)

func on_guest_injured(guest: NPCGuest) -> void:
	on_npc_injured(guest)

func on_npc_recovered(npc: NPC) -> void:
	if npc == null:
		return
	_injured.erase(npc)
	_next_guest_penalty_time.erase(npc)
	var guest := npc as NPCGuest
	if guest != null:
		guest_recovered.emit(guest)
	npc_recovered.emit(npc)

func on_guest_recovered(guest: NPCGuest) -> void:
	on_npc_recovered(guest)

func get_injured_npcs() -> Array[NPC]:
	for i: int in range(_injured.size() - 1, -1, -1):
		if not is_instance_valid(_injured[i]):
			_next_guest_penalty_time.erase(_injured[i])
			_injured.remove_at(i)
	return _injured

func get_injured_guests() -> Array[NPCGuest]:
	var injured_guests: Array[NPCGuest] = []
	for injured: NPC in get_injured_npcs():
		var guest := injured as NPCGuest
		if guest != null:
			injured_guests.append(guest)
	return injured_guests

func can_receive_treatment_now(npc: NPC) -> bool:
	if npc == null or not is_instance_valid(npc):
		return false
	if npc.Status == null or not npc.Status.has_status(Enum.NpcStatus.INJURED):
		return false

	var behaviour := npc.Behaviour.behaviour_instance if npc.Behaviour != null else null
	if behaviour is KnockedOutBehaviour or behaviour is ArrestedBehaviour or behaviour is FollowSheriffBehaviour:
		return false

	var guest := npc as NPCGuest
	if guest != null and ConflictResponseHandler.is_marked_for_arrest(guest):
		return false

	return true

func should_seek_treatment_behaviour(npc: NPC) -> bool:
	return get_treatment_behaviour(npc) != null

func get_treatment_behaviour(npc: NPC):
	if not can_receive_treatment_now(npc):
		return null
	if find_barber_surgeon_provider(npc) != null:
		return NEED_BARBER_SURGEON_TREATMENT_BEHAVIOUR
	if find_treatment_infirmary(npc) != null:
		return NEED_TREATMENT_BEHAVIOUR
	return null

func find_barber_surgeon_provider(npc: NPC):
	if npc == null or not is_instance_valid(npc) or npc.Navigation == null or Global.NPCSpawner == null:
		return null

	var best_provider = null
	var best_distance := INF

	for special: SpecialNPC in Global.NPCSpawner.special_npcs:
		if not is_instance_valid(special) or special.Behaviour == null:
			continue

		var behaviour := special.Behaviour.behaviour_instance
		if behaviour == null or behaviour.get_script() != BARBER_SURGEON_BEHAVIOUR:
			continue

		var provider = behaviour
		var assigned_table = provider.get_assigned_table()
		if assigned_table == null or not provider.accepts_patient(npc):
			continue
		if not npc.Navigation.is_room_reachable(assigned_table):
			continue

		var distance := npc.global_position.distance_squared_to(provider.get_waiting_room_position())
		if distance < best_distance:
			best_distance = distance
			best_provider = provider

	return best_provider

func find_treatment_infirmary(npc: NPC, require_staffed := false) -> RoomInfirmary:
	if npc == null or not is_instance_valid(npc) or npc.Navigation == null:
		return null

	var reachable := npc.Navigation.get_reachable_rooms()
	for room: RoomInfirmary in Building.query.rooms_of_type_ordered_by_distance(RoomInfirmary, npc.global_position, null, reachable):
		if not room.accepts_patient(npc):
			continue
		if require_staffed and (room.worker == null or not is_instance_valid(room.worker)):
			continue
		return room
	return null

func apply_treatment(npc: NPC, quality: float, infirmary: RoomInfirmary = null) -> void:
	if npc == null or not is_instance_valid(npc) or npc.Status == null:
		return

	if npc is NPCGuest and infirmary != null and is_instance_valid(infirmary):
		_recovery_payment_sources[npc] = infirmary

	npc.Status.clear_status(Enum.NpcStatus.INJURED)
	npc.Status.clear_status(Enum.NpcStatus.WELL_TREATED)
	npc.Status.clear_status(Enum.NpcStatus.BADLY_TREATED)

	if quality >= GOOD_TREATMENT_THRESHOLD:
		npc.Status.set_status(Enum.NpcStatus.WELL_TREATED)
	else:
		npc.Status.set_status(Enum.NpcStatus.BADLY_TREATED)

	on_npc_recovered(npc)

func collect_recovery_payment(npc: NPC) -> void:
	var guest := npc as NPCGuest
	if guest == null:
		return

	var infirmary := _recovery_payment_sources.get(guest, null) as RoomInfirmary
	_recovery_payment_sources.erase(guest)

	if infirmary == null or not is_instance_valid(infirmary):
		return

	var price := infirmary.get_service_price()
	if price <= 0:
		return

	ResourceHandler.add_animated(
		Enum.Resources.MONEY,
		price,
		guest.global_position,
		Vector2i(infirmary.x, infirmary.y)
	)

func _process(_delta: float) -> void:
	_clear_invalid_payment_sources()
	var injured_npcs := get_injured_npcs()
	_sync_treatment_behaviours(injured_npcs.duplicate())
	_apply_guest_penalties(injured_npcs.duplicate())

func _sync_treatment_behaviours(injured_npcs: Array[NPC]) -> void:
	for injured: NPC in injured_npcs:
		var treatment_behaviour = get_treatment_behaviour(injured)
		if treatment_behaviour == null:
			continue
		if injured.Behaviour == null:
			continue

		var behaviour := injured.Behaviour.behaviour_instance
		if behaviour != null and behaviour.get_script() == treatment_behaviour:
			continue

		injured.force_behaviour(treatment_behaviour)

func _apply_guest_penalties(injured_npcs: Array[NPC]) -> void:
	for injured: NPC in injured_npcs:
		var guest := injured as NPCGuest
		if guest == null or not _should_keep_npc_injured(guest):
			continue
		if guest.Behaviour != null and guest.Behaviour.behaviour_instance is KnockedOutBehaviour:
			continue

		var next_tick: float = float(_next_guest_penalty_time.get(guest, Global.time_now + UNTREATED_INJURY_TICK_SECONDS))
		if Global.time_now < next_tick:
			continue

		guest.add_satisfaction(-UNTREATED_INJURY_SATISFACTION_LOSS, "Untreated Injury")
		_next_guest_penalty_time[guest] = Global.time_now + UNTREATED_INJURY_TICK_SECONDS

func _should_keep_npc_injured(npc: NPC) -> bool:
	return is_instance_valid(npc) and npc.Status != null and npc.Status.has_status(Enum.NpcStatus.INJURED)

func _clear_invalid_payment_sources() -> void:
	for npc: NPC in _recovery_payment_sources.keys():
		if not is_instance_valid(npc):
			_recovery_payment_sources.erase(npc)
