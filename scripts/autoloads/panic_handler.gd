extends Node

const PanicBehaviourScript = preload("res://scripts/npc/behaviours/panic_behaviour.gd")

var _reason_to_npcs := {}
var _npc_to_reasons := {}

func _ready() -> void:
	NPCEventHandler.on_destroy_npc_signal.connect(_on_npc_destroyed)

func start_panic(npc: NPC, reason, threat_room: RoomBase, threat_position: Vector2) -> bool:
	if not _can_track_npc(npc) or reason == null:
		return false

	_cleanup_npc_if_not_panicking(npc)

	var npc_reasons: Array = _npc_to_reasons.get(npc, [])
	if npc_reasons.has(reason):
		return false

	_add_reason_for_npc(npc, reason)

	if _is_panicking(npc):
		_redirect_existing_panic(npc, threat_room, threat_position)
		return true

	var panic_data := BehaviourSaveData.new(PanicBehaviourScript)
	panic_data.extra["threat_room"] = threat_room
	panic_data.extra["threat_position"] = threat_position
	npc.Behaviour.set_behaviour(PanicBehaviourScript, panic_data)
	return true

func clear_reason(reason) -> void:
	if reason == null or not _reason_to_npcs.has(reason):
		return

	var affected: Array = _reason_to_npcs.get(reason, [])
	affected = affected.duplicate()
	_reason_to_npcs.erase(reason)

	for npc: NPC in affected:
		if not is_instance_valid(npc):
			continue
		var npc_reasons: Array = _npc_to_reasons.get(npc, [])
		npc_reasons.erase(reason)
		if npc_reasons.is_empty():
			_npc_to_reasons.erase(npc)
			_release_npc(npc)
		else:
			_npc_to_reasons[npc] = npc_reasons

func has_reason(npc: NPC, reason) -> bool:
	if not _can_track_npc(npc) or reason == null:
		return false
	var npc_reasons: Array = _npc_to_reasons.get(npc, [])
	return npc_reasons.has(reason)

func _add_reason_for_npc(npc: NPC, reason) -> void:
	var npc_reasons: Array = _npc_to_reasons.get(npc, [])
	npc_reasons.append(reason)
	_npc_to_reasons[npc] = npc_reasons

	var affected: Array = _reason_to_npcs.get(reason, [])
	affected.append(npc)
	_reason_to_npcs[reason] = affected

func _release_npc(npc: NPC) -> void:
	if not _can_track_npc(npc):
		return
	if not _is_panicking(npc):
		return

	npc.Behaviour.clear_behaviour()
	if not is_instance_valid(npc) or npc.Behaviour == null or npc.Behaviour.has_behaviour:
		return

	if npc is NPCWorker:
		(npc as NPCWorker).resume_job_behaviour()
	elif npc is NPCGuest:
		(npc as NPCGuest).resume_autonomous_behaviour()

func _redirect_existing_panic(npc: NPC, threat_room: RoomBase, threat_position: Vector2) -> void:
	if not _is_panicking(npc):
		return
	var current := npc.Behaviour.behaviour_instance
	if current == null:
		return
	if current.has_method("register_threat"):
		current.register_threat(threat_room, threat_position)

func _cleanup_npc_if_not_panicking(npc: NPC) -> void:
	if not _npc_to_reasons.has(npc):
		return
	if _is_panicking(npc):
		return
	_forget_npc(npc)

func _forget_npc(npc: NPC) -> void:
	var npc_reasons: Array = _npc_to_reasons.get(npc, [])
	for reason in npc_reasons:
		var affected: Array = _reason_to_npcs.get(reason, [])
		affected.erase(npc)
		if affected.is_empty():
			_reason_to_npcs.erase(reason)
		else:
			_reason_to_npcs[reason] = affected
	_npc_to_reasons.erase(npc)

func _is_panicking(npc: NPC) -> bool:
	if not _can_track_npc(npc):
		return false
	var current = npc.Behaviour.behaviour_instance
	return current != null and current.get_script() == PanicBehaviourScript

func _can_track_npc(npc: NPC) -> bool:
	return is_instance_valid(npc) and npc.Behaviour != null

func _on_npc_destroyed(npc: NPC) -> void:
	if npc == null:
		return
	_forget_npc(npc)
