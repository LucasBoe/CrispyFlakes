class_name Fight

enum FightType {
	BRAWL,
	ARREST,
	ROBBERY,
}

enum State {
	GATHERING,
	ACTIVE,
	OVER,
}

enum Result {
	NONE,
	WORKERS_WON,
	NO_CONTEST,
}

var participants = []
var target_mapping : Dictionary[NPC, NPC] = {}
var fight_positions: Dictionary = {}  # Dictionary[NPC, Vector2]
var last_attack : Dictionary[NPC, float] = {}
var health_bars := {}
var room : RoomBase
var highlight

var debug_id: int = -1
var fight_type: FightType = FightType.BRAWL
var state: State = State.GATHERING
var result: Result = Result.NONE
var has_started: bool = false
var is_over: bool = false

const DRUNK_FIGHT_BOUNTY: int = 10
const MELEE_ATTACK_RANGE: float = 16.0
const MELEE_ATTACK_SPEED: float = 0.8
const MELEE_DAMAGE: float = 0.2
const MELEE_ARRIVE_THRESHOLD: float = 2.0

func get_active_participants() -> Array:
	var active := []
	for participant in participants:
		var npc := participant as NPC
		if not is_instance_valid(npc) or npc.Behaviour == null:
			continue
		var b = npc.Behaviour.behaviour_instance
		if b is ArrestedBehaviour or b is KnockedOutBehaviour:
			continue
		if b is FightBehaviour:
			if (b as FightBehaviour).arrived_at_room:
				active.append(npc)
	return active

func debug_label() -> String:
	return "#%d %s %s %s" % [debug_id, FightType.keys()[fight_type], State.keys()[state], Result.keys()[result]]

func _debug(message: String) -> void:
	print("[Fight %s] %s" % [debug_label(), message])

func _npc_debug(npc: NPC) -> String:
	if not is_instance_valid(npc):
		return "<invalid>"
	var behaviour_name := "<none>"
	if npc.Behaviour != null and npc.Behaviour.behaviour_instance != null:
		behaviour_name = npc.Behaviour.behaviour_instance.get_script().resource_path.get_file()
	var fight_behaviour := _get_fight_behaviour(npc)
	return "%s(%s energy=%.2f behaviour=%s arrived=%s)" % [
		npc.name,
		"worker" if npc is NPCWorker else "guest",
		npc.energy,
		behaviour_name,
		fight_behaviour != null and fight_behaviour.arrived_at_room,
	]

func _participants_debug(list = null) -> String:
	if list == null:
		list = participants
	var entries := PackedStringArray()
	for participant in list:
		entries.append(_npc_debug(participant as NPC))
	return "; ".join(entries)

func has_participant(npc: NPC) -> bool:
	return participants.has(npc)

func make_join_fight(npc: NPC) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	if not has_participant(npc):
		participants.append(npc)
		_debug("join %s" % _npc_debug(npc))
	if not (npc.Behaviour.behaviour_instance is FightBehaviour):
		npc.Behaviour.set_behaviour(FightBehaviour)
	var behaviour := npc.Behaviour.behaviour_instance as FightBehaviour
	behaviour.fight = self

func start_fight():
	state = State.ACTIVE
	has_started = true
	_debug("start active=%s all=%s" % [_participants_debug(get_active_participants()), _participants_debug()])
	if room != null:
		highlight = RoomHighlighter.request_rect(room, Color.RED, 2, RoomHighlighter.Priority.FIGHT)

func handle_fight():
	var active_participants := get_active_participants()
	_cleanup_inactive_participants(active_participants)

	if _try_resolve(active_participants):
		return

	_sync_health_bars(active_participants)
	_assign_targets(active_participants)

	for participant: NPC in active_participants:
		var target := target_mapping.get(participant) as NPC
		if target == null or not active_participants.has(target):
			continue

		var to_target := target.global_position - participant.global_position
		if participant.Animator != null and to_target.x != 0.0:
			participant.Animator.x_orientation = sign(to_target.x)

		var fight_pos: Vector2 = fight_positions.get(participant, Vector2.INF)
		if fight_pos == Vector2.INF:
			continue

		if participant.global_position.distance_to(fight_pos) > MELEE_ARRIVE_THRESHOLD:
			_move_to_fight_position(participant, fight_pos)
			continue

		_hold_position_for_attack(participant)
		_try_attack(participant, target)

	_check_for_knockouts()
	active_participants = get_active_participants()
	_sync_health_bars(active_participants)
	_try_resolve(active_participants)

func _assign_targets(active_participants: Array) -> void:
	for participant: NPC in active_participants:
		var target := target_mapping.get(participant) as NPC
		if target != null and active_participants.has(target):
			continue
		var new_target := _pick_target_for(participant, active_participants)
		target_mapping[participant] = new_target
		if new_target != null:
			_compute_fight_positions(participant, new_target)

func _pick_target_for(participant: NPC, active_participants: Array) -> NPC:
	var candidates := []
	for candidate: NPC in active_participants:
		if candidate != participant and _can_target(participant, candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		return null
	return candidates.pick_random()

func _can_target(attacker: NPC, target: NPC) -> bool:
	if attacker is NPCWorker and target is NPCWorker:
		return false
	return true

func _compute_fight_positions(a: NPC, b: NPC) -> void:
	var dir := a.global_position - b.global_position
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var mid := (a.global_position + b.global_position) / 2.0
	# Place each NPC on opposite sides of the midpoint, MELEE_ATTACK_RANGE apart total
	fight_positions[a] = mid + dir * (MELEE_ATTACK_RANGE / 2.0)
	fight_positions[b] = mid - dir * (MELEE_ATTACK_RANGE / 2.0)

func _move_to_fight_position(participant: NPC, pos: Vector2) -> void:
	if participant.Navigation == null:
		return
	if participant.Navigation.target_final != pos or not participant.Navigation.is_moving:
		participant.Navigation.set_target(pos, -1)

func _hold_position_for_attack(participant: NPC) -> void:
	if participant.Navigation != null and participant.Navigation.is_moving:
		participant.Navigation.stop_navigation()

func _try_attack(attacker: NPC, target: NPC) -> void:
	var last_attack_time := float(last_attack.get(attacker, -MELEE_ATTACK_SPEED))
	var time_since_last_attack := Global.time_now - last_attack_time
	if time_since_last_attack < MELEE_ATTACK_SPEED:
		return

	var target_behaviour := _get_fight_behaviour(target)
	if target_behaviour == null:
		return

	var damage := _get_attack_damage(attacker)
	target.energy = maxf(0.0, target.energy - damage)
	last_attack[attacker] = Global.time_now
	SoundPlayer.play_punch(attacker.global_position)
	if target.energy <= 0.0:
		_debug("hit KO %s -> %s damage=%.2f active_before_cleanup=%s" % [
			_npc_debug(attacker),
			_npc_debug(target),
			damage,
			_participants_debug(get_active_participants()),
		])

	var target_target := target_mapping.get(target) as NPC
	if target_target != attacker and _get_fight_behaviour(target) != null:
		target_mapping[target] = attacker
		_compute_fight_positions(target, attacker)

func _get_attack_damage(attacker: NPC) -> float:
	return MELEE_DAMAGE * (0.5 + attacker.strength * 0.5)

func _check_for_knockouts() -> void:
	for participant: NPC in participants:
		var behaviour := _get_fight_behaviour(participant)
		if behaviour == null or participant.energy > 0.0:
			continue
		_knock_out(participant)

func _knock_out(npc: NPC) -> void:
	target_mapping.erase(npc)
	fight_positions.erase(npc)
	last_attack.erase(npc)
	for attacker in target_mapping.keys():
		if target_mapping[attacker] == npc:
			target_mapping.erase(attacker)

	if npc.Navigation != null:
		npc.Navigation.stop_navigation()
	_debug("knockout %s participants=%s" % [_npc_debug(npc), _participants_debug()])
	npc.Behaviour.set_behaviour(KnockedOutBehaviour)

func clear_health_bars() -> void:
	for npc in health_bars.keys():
		UiNotifications.try_kill(health_bars[npc])
	health_bars.clear()

func _sync_health_bars(active_participants: Array) -> void:
	for npc in health_bars.keys():
		if not is_instance_valid(npc) or not active_participants.has(npc):
			UiNotifications.try_kill(health_bars[npc])
			health_bars.erase(npc)

	for participant: NPC in active_participants:
		var behaviour := _get_fight_behaviour(participant)
		if behaviour == null:
			continue
		if not health_bars.has(participant):
			health_bars[participant] = UiNotifications.create_npc_health_bar(participant, _health_bar_color(participant))
		UiNotifications.update_npc_health_bar(health_bars[participant], participant.energy)

func _health_bar_color(npc: NPC) -> Color:
	if npc is NPCWorker:
		return Color.GREEN
	return Color.RED

func _try_resolve(active_participants: Array) -> bool:
	var next_result := _get_result(active_participants)
	if next_result == Result.NONE:
		return false
	_debug("resolve candidate %s active=%s all=%s" % [
		Result.keys()[next_result],
		_participants_debug(active_participants),
		_participants_debug(),
	])
	resolve(next_result)
	return true

func resolve(next_result: Result) -> bool:
	if state == State.OVER:
		return false
	result = next_result
	state = State.OVER
	is_over = true
	_debug("resolve apply %s" % Result.keys()[result])
	_apply_result()
	FightHandler.end_fight(self)
	return true

func _get_result(active_participants: Array) -> Result:
	if active_participants.size() <= 1:
		if active_participants.size() == 1:
			var survivor := active_participants[0] as NPC
			if survivor is NPCWorker:
				return Result.WORKERS_WON
			if survivor is NPCGuest:
				return Result.NO_CONTEST
		return Result.NO_CONTEST

	var has_active_worker := false
	var has_active_guest := false
	for participant: NPC in active_participants:
		if participant is NPCWorker:
			has_active_worker = true
		elif participant is NPCGuest:
			has_active_guest = true

	if has_active_worker and not has_active_guest:
		return Result.WORKERS_WON
	if has_active_guest and not has_active_worker:
		if fight_type == FightType.BRAWL:
			return Result.NONE
		return Result.NO_CONTEST
	return Result.NONE

func _apply_result() -> void:
	if result == Result.WORKERS_WON:
		_apply_workers_won()

func _apply_workers_won() -> void:
	for participant in participants:
		var guest := participant as NPCGuest
		if not is_instance_valid(guest):
			continue
		if not _should_apply_worker_win_to_guest(guest):
			_debug("worker win skip %s" % _npc_debug(guest))
			continue
		_debug("worker win apply %s" % _npc_debug(guest))
		if fight_type == FightType.BRAWL and guest.look_info != null:
			BountyHandler.create_fight_fine(guest, DRUNK_FIGHT_BOUNTY)
		ConflictResponseHandler.unmark_for_arrest(guest)
		guest.force_behaviour(ArrestedBehaviour)

func _should_apply_worker_win_to_guest(guest: NPCGuest) -> bool:
	var behaviour = guest.Behaviour.behaviour_instance
	return behaviour is FightBehaviour or behaviour is KnockedOutBehaviour

func _cleanup_inactive_participants(active_participants: Array) -> void:
	for i: int in range(participants.size() - 1, -1, -1):
		var participant := participants[i] as NPC
		if not is_instance_valid(participant):
			participants.remove_at(i)

	for participant in target_mapping.keys():
		var target := target_mapping[participant] as NPC
		if not is_instance_valid(participant) or not is_instance_valid(target):
			target_mapping.erase(participant)
			continue
		if not active_participants.has(participant) or not active_participants.has(target):
			target_mapping.erase(participant)

	for participant in last_attack.keys():
		if not is_instance_valid(participant) or not active_participants.has(participant):
			last_attack.erase(participant)

	for participant in fight_positions.keys():
		if not is_instance_valid(participant) or not active_participants.has(participant):
			fight_positions.erase(participant)

func _get_fight_behaviour(npc: NPC) -> FightBehaviour:
	if npc == null or not is_instance_valid(npc) or npc.Behaviour == null:
		return null
	return npc.Behaviour.behaviour_instance as FightBehaviour
