extends Node

var potential_arrests: Array[NPCGuest] = []

func mark_for_arrest(guest: NPCGuest) -> void:
	if not potential_arrests.has(guest):
		potential_arrests.append(guest)

func unmark_for_arrest(guest: NPCGuest) -> void:
	potential_arrests.erase(guest)

func is_marked_for_arrest(guest: NPCGuest) -> bool:
	return potential_arrests.has(guest)

func _process(_delta: float) -> void:
	if Global.NPCSpawner == null:
		return
	_refresh_potential_arrests()
	_try_pair_arrests()
	_try_join_brawls()

func try_join_brawl(fight: Fight) -> bool:
	if Global.NPCSpawner == null:
		return false
	if not _can_join_brawl(fight):
		return false

	var response_position := _get_fight_response_position(fight)
	if response_position == Vector2.INF:
		return false

	var joined := false
	for worker: NPCWorker in Global.NPCSpawner.workers:
		if not _can_worker_respond(worker, response_position):
			continue
		if fight.has_participant(worker):
			continue
		fight.make_join_fight(worker)
		joined = true
	return joined

func _refresh_potential_arrests() -> void:
	for i: int in range(potential_arrests.size() - 1, -1, -1):
		var guest: NPCGuest = potential_arrests[i]
		if not is_instance_valid(guest) or _is_in_active_fight(guest):
			potential_arrests.remove_at(i)

func _try_pair_arrests() -> void:
	if potential_arrests.is_empty():
		return

	for guest: NPCGuest in potential_arrests:
		var worker := _find_responder_for_position(guest.global_position)
		if worker != null:
			FightHandler.create_defense_fight(guest, worker)

func _try_join_brawls() -> void:
	for fight: Fight in FightHandler.active_fights:
		try_join_brawl(fight)

func _find_responder_for_position(position: Vector2) -> NPCWorker:
	for worker: NPCWorker in Global.NPCSpawner.workers:
		if _can_worker_respond(worker, position):
			return worker
	return null

func _can_worker_respond(worker: NPCWorker, position: Vector2) -> bool:
	if not is_instance_valid(worker):
		return false
	if worker.saloon_fight_response != NPCWorker.SaloonFightResponse.FIGHT:
		return false
	if NPCWorker.picked_up_npc == worker:
		return false
	if worker.Behaviour == null or worker.Behaviour.behaviour_instance is FightBehaviour:
		return false
	if worker.Behaviour.behaviour_instance is KnockedOutBehaviour:
		return false
	return FightHandler.is_within_fight_detection_range(worker.global_position, position)

func _can_join_brawl(fight: Fight) -> bool:
	if fight == null or not is_instance_valid(fight):
		return false
	if fight.is_over or fight.fight_type == Fight.FightType.ARREST:
		return false
	if fight.room == null:
		return false
	return _has_active_guest_participant(fight)

func _has_active_guest_participant(fight: Fight) -> bool:
	for participant in fight.participants:
		var guest := participant as NPCGuest
		if is_instance_valid(guest):
			return true
	return false

func _get_fight_response_position(fight: Fight) -> Vector2:
	for participant in fight.participants:
		var npc := participant as NPC
		if is_instance_valid(npc):
			return npc.global_position
	if fight.room != null:
		return fight.room.get_center_position()
	return Vector2.INF

func _is_in_active_fight(guest: NPCGuest) -> bool:
	for fight: Fight in FightHandler.active_fights:
		if fight.has_participant(guest):
			return true
	return false
