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

enum JoinReason {
	UNKNOWN,
	BRAWL_INITIATOR,
	BRAWL_DRAWN_IN,
	WORKER_RESPONSE,
	ARREST_TARGET,
	ARREST_RESPONSE,
	ROBBERY_PERPETRATOR,
	ROBBERY_RESPONSE,
}

var participants = []
var target_mapping: Dictionary[NPC, NPC] = {}
var fight_positions: Dictionary = {}
var last_attack: Dictionary[NPC, float] = {}
var attack_intervals: Dictionary[NPC, float] = {}
var pending_attacks: Dictionary[NPC, Dictionary] = {}
var participant_join_reasons: Dictionary = {}
var health_bars := {}
var room : RoomBase
var opening_attacker: NPC = null
var opening_strike_resolved: bool = false

var debug_id: int = -1
var fight_type: FightType = FightType.BRAWL
var state: State = State.GATHERING
var result: Result = Result.NONE
var has_started: bool = false
var is_over: bool = false
var start_not_before_time: float = 0.0
var keep_alive_until_time: float = 0.0

const GUTLESS_ROBBER_ESCAPE_CHANCE: float = 0.5
const MELEE_ATTACK_RANGE: float = 16.0
const MELEE_ATTACK_SPEED: float = 0.8
const MELEE_ATTACK_SPEED_VARIATION: float = 0.12
const MELEE_DAMAGE_DELAY: float = 0.25
const MELEE_DAMAGE: float = 0.12
const MELEE_ARRIVE_THRESHOLD: float = 2.0
const INJURY_INSTEAD_OF_KO_CHANCE: float = 0.8
const INJURY_MIN_SURVIVE_ENERGY: float = 0.08

func get_active_participants() -> Array:
	var active := []
	for participant in participants:
		if not is_instance_valid(participant):
			continue
		var npc := participant as NPC
		if not is_instance_valid(npc) or npc.Behaviour == null:
			continue
		if not FightHandler.can_npc_participate_in_fights(npc):
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
		if not is_instance_valid(participant):
			entries.append("<freed>")
			continue
		entries.append(_npc_debug(participant as NPC))
	return "; ".join(entries)

func has_participant(npc: NPC) -> bool:
	return participants.has(npc)

func make_join_fight(npc: NPC, join_reason: int = JoinReason.UNKNOWN) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	if not FightHandler.can_npc_participate_in_fights(npc):
		return
	var was_participant := has_participant(npc)
	var resolved_join_reason := _resolve_join_reason(npc, join_reason, was_participant)
	if not was_participant:
		participants.append(npc)
		_debug("join %s reason=%s" % [_npc_debug(npc), JoinReason.keys()[resolved_join_reason]])
	_register_join_reason(npc, resolved_join_reason)
	_register_opening_attacker(npc, resolved_join_reason)
	if not (npc.Behaviour.behaviour_instance is FightBehaviour):
		npc.Behaviour.set_behaviour(FightBehaviour)
	var behaviour := npc.Behaviour.behaviour_instance as FightBehaviour
	behaviour.fight = self

func _register_opening_attacker(npc: NPC, join_reason: int) -> void:
	if opening_attacker != null and is_instance_valid(opening_attacker):
		return
	match join_reason:
		JoinReason.BRAWL_INITIATOR, JoinReason.ROBBERY_PERPETRATOR, JoinReason.ARREST_RESPONSE:
			opening_attacker = npc

func did_participant_start_brawl(npc: NPC) -> bool:
	return int(participant_join_reasons.get(npc, JoinReason.UNKNOWN)) == JoinReason.BRAWL_INITIATOR

func _has_brawl_initiator() -> bool:
	for reason in participant_join_reasons.values():
		if int(reason) == JoinReason.BRAWL_INITIATOR:
			return true
	return false

func _resolve_join_reason(npc: NPC, join_reason: int, was_participant: bool) -> int:
	if join_reason != JoinReason.UNKNOWN:
		return join_reason
	if was_participant:
		return int(participant_join_reasons.get(npc, JoinReason.UNKNOWN))

	match fight_type:
		FightType.BRAWL:
			if npc is NPCWorker:
				return JoinReason.WORKER_RESPONSE
			if npc is NPCGuest:
				return JoinReason.BRAWL_DRAWN_IN if _has_brawl_initiator() else JoinReason.BRAWL_INITIATOR
		FightType.ARREST:
			if npc is NPCWorker:
				return JoinReason.ARREST_RESPONSE
			if npc is NPCGuest:
				return JoinReason.ARREST_TARGET
		FightType.ROBBERY:
			if npc is NPCWorker:
				return JoinReason.ROBBERY_RESPONSE
			if npc is NPCGuest:
				return JoinReason.ROBBERY_PERPETRATOR
	return JoinReason.UNKNOWN

func _register_join_reason(npc: NPC, join_reason: int) -> void:
	if join_reason == JoinReason.UNKNOWN and participant_join_reasons.has(npc):
		return
	participant_join_reasons[npc] = join_reason

func start_fight():
	state = State.ACTIVE
	has_started = true
	if fight_type != FightType.ROBBERY:
		AlarmHandler.start_alarm(self, AlarmHandler.TYPE_FIGHT)
	_debug("start active=%s all=%s" % [_participants_debug(get_active_participants()), _participants_debug()])
	if _try_resolve_gutless_arrest_target():
		return

func _try_resolve_gutless_arrest_target() -> bool:
	if fight_type != FightType.ARREST:
		return false

	var guest := _get_gutless_arrest_target()
	if guest == null:
		return false

		_return_guest_stolen_money(guest, "[Fight] Gutless robber surrender")
		if _should_gutless_robber_flee(guest) and randf() < GUTLESS_ROBBER_ESCAPE_CHANCE:
			_debug("gutless arrest target fled %s" % _npc_debug(guest))
			_force_guest_to_flee(guest)
			resolve(Result.NO_CONTEST)
			return true

	_debug("gutless arrest target surrendered %s" % _npc_debug(guest))
	resolve(Result.WORKERS_WON)
	return true

func _get_gutless_arrest_target() -> NPCGuest:
	for participant in participants:
		if not is_instance_valid(participant):
			continue
		var guest := participant as NPCGuest
		if not is_instance_valid(guest):
			continue
		if int(participant_join_reasons.get(guest, JoinReason.UNKNOWN)) != JoinReason.ARREST_TARGET:
			continue
		if guest.Traits != null and guest.Traits.refuses_voluntary_fights():
			return guest
	return null

func _should_gutless_robber_flee(guest: NPCGuest) -> bool:
	return guest.is_robber or guest.stolen_amount > 0

func _force_guest_to_flee(guest: NPCGuest) -> void:
	guest.is_robber = false
	if guest.has_meta("horse"):
		guest.force_behaviour(LeaveOnHorseBehaviour)
	else:
		guest.force_behaviour(NeedLeaveBehaviour)

func _return_guest_stolen_money(guest: NPCGuest, log_prefix: String = "[Fight] Returning stolen money") -> void:
	if guest.stolen_amount <= 0:
		return
	if guest.Item != null and guest.Item.is_item(Enum.Items.MONEY):
		var carried := guest.Item.drop_current()
		if is_instance_valid(carried):
			carried.destroy()
	var room := Building.query.room_at_floor_position(guest.global_position) as RoomBase
	ResourceHandler.add_animated_money_to_room_or_floor(guest.stolen_amount, guest.global_position, room)
	print("%s guest=%s amount=%d" % [log_prefix, guest.name, guest.stolen_amount])
	guest.stolen_amount = 0

func handle_fight():
	var active_participants := get_active_participants()
	_cleanup_inactive_participants(active_participants)
	_apply_pending_attacks(active_participants)
	_check_for_knockouts()
	active_participants = get_active_participants()
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
	if _is_law_side_participant(attacker) and _is_law_side_participant(target):
		return false
	return true

func _compute_fight_positions(a: NPC, b: NPC) -> void:
	var dir = a.global_position - b.global_position
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
	if pending_attacks.has(attacker):
		return

	var attack_interval := _get_attack_interval(attacker)
	if not last_attack.has(attacker):
		if _has_opening_attacker() and _is_opening_attacker(attacker) and not opening_strike_resolved:
			last_attack[attacker] = Global.time_now - attack_interval
		else:
			last_attack[attacker] = Global.time_now - randf_range(0.0, attack_interval)
		return

	var last_attack_time := float(last_attack.get(attacker, -attack_interval))
	var time_since_last_attack := Global.time_now - last_attack_time
	if time_since_last_attack < attack_interval:
		return

	var target_behaviour := _get_fight_behaviour(target)
	if target_behaviour == null:
		return

	last_attack[attacker] = Global.time_now
	if attacker.Animator != null:
		var attack_direction: float = sign(target.global_position.x - attacker.global_position.x)
		if is_zero_approx(attack_direction):
			attack_direction = float(attacker.Animator.x_orientation)
		attacker.Animator.play_fight_punch(attack_direction)
	pending_attacks[attacker] = {
		"target": target,
		"damage": _get_attack_damage(attacker, target),
		"apply_time": Global.time_now + MELEE_DAMAGE_DELAY,
	}

func _get_attack_interval(attacker: NPC) -> float:
	if not attack_intervals.has(attacker):
		attack_intervals[attacker] = maxf(0.35, MELEE_ATTACK_SPEED + randf_range(-MELEE_ATTACK_SPEED_VARIATION, MELEE_ATTACK_SPEED_VARIATION))
	return float(attack_intervals[attacker])

func _apply_pending_attacks(active_participants: Array) -> void:
	for attacker in pending_attacks.keys().duplicate():
		if not is_instance_valid(attacker):
			pending_attacks.erase(attacker)
			continue
		if not pending_attacks.has(attacker):
			continue
		var attack: Dictionary = pending_attacks[attacker]
		if Global.time_now < float(attack.get("apply_time", 0.0)):
			continue

		pending_attacks.erase(attacker)

		var target := attack.get("target", null) as NPC
		if not _can_apply_pending_attack(attacker, target, active_participants):
			continue
		if _has_opening_attacker() and not opening_strike_resolved and not _is_opening_attacker(attacker):
			continue

		var damage := float(attack.get("damage", 0.0))
		if _has_opening_attacker() and not opening_strike_resolved and _is_opening_attacker(attacker):
			opening_strike_resolved = true
		_play_hit_impact(attacker, target)
		var target_energy_after_hit := maxf(0.0, target.energy - damage)
		if _should_convert_knockout_to_injury(target, target_energy_after_hit):
			target.energy = maxf(target_energy_after_hit, INJURY_MIN_SURVIVE_ENERGY)
			_injure_participant(target)
			_debug("hit injury %s -> %s damage=%.2f active_before_cleanup=%s" % [
				_npc_debug(attacker),
				_npc_debug(target),
				damage,
				_participants_debug(get_active_participants()),
			])
			continue

		target.energy = target_energy_after_hit
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

func _can_apply_pending_attack(attacker: NPC, target: NPC, active_participants: Array) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	if not active_participants.has(attacker) or not active_participants.has(target):
		return false
	if _get_fight_behaviour(attacker) == null or _get_fight_behaviour(target) == null:
		return false
	return true

func _get_attack_damage(attacker: NPC, target: NPC) -> float:
	var outgoing = attacker.Traits.get_melee_damage_multiplier()
	var incoming = target.Traits.get_incoming_damage_multiplier()
	return MELEE_DAMAGE * outgoing * incoming

func _play_hit_impact(attacker: NPC, target: NPC) -> void:
	SoundPlayer.play_punch(attacker.global_position)
	if target.Animator == null:
		return
	var impact_direction: float = sign(target.global_position.x - attacker.global_position.x)
	if is_zero_approx(impact_direction):
		if attacker.Animator != null and attacker.Animator.x_orientation != 0:
			impact_direction = float(attacker.Animator.x_orientation)
		else:
			impact_direction = 1.0
	target.Animator.play_fight_hit_reaction(impact_direction)

func _mark_robber_for_arrest_if_worker_injury_resolves_fight(injured_npc: NPC) -> void:
	if fight_type != FightType.ROBBERY or not (injured_npc is NPCWorker):
		return
	if _get_result(get_active_participants()) != Result.NO_CONTEST:
		return
	for participant in participants:
		var guest := participant as NPCGuest
		if not is_instance_valid(guest):
			continue
		if int(participant_join_reasons.get(guest, JoinReason.UNKNOWN)) != JoinReason.ROBBERY_PERPETRATOR:
			continue
		ConflictResponseHandler.mark_for_arrest(guest)
		_debug("worker injury auto-marked robber for arrest %s" % _npc_debug(guest))

func _is_opening_attacker(npc: NPC) -> bool:
	return npc != null and opening_attacker == npc and is_instance_valid(opening_attacker)

func _has_opening_attacker() -> bool:
	return opening_attacker != null and is_instance_valid(opening_attacker)

func _check_for_knockouts() -> void:
	for participant: NPC in participants:
		var behaviour := _get_fight_behaviour(participant)
		if behaviour == null or participant.energy > 0.0:
			continue
		_knock_out(participant)

func _knock_out(npc: NPC) -> void:
	_remove_participant_from_fight(npc)
	_debug("knockout %s participants=%s" % [_npc_debug(npc), _participants_debug()])
	npc.Behaviour.set_behaviour(KnockedOutBehaviour)
	if InjuryHandler.try_injure_npc(npc):
		print("[Fight] %s knocked out and marked INJURED — fight_type=%s" % [
			"Guest" if npc is NPCGuest else "Worker",
			FightType.keys()[fight_type]
		])

func _injure_participant(npc: NPC) -> void:
	_remove_participant_from_fight(npc)
	if InjuryHandler.try_injure_npc(npc):
		print("[Fight] %s injured and removed from fight — fight_type=%s" % [
			"Guest" if npc is NPCGuest else "Worker",
			FightType.keys()[fight_type]
		])
		_mark_robber_for_arrest_if_worker_injury_resolves_fight(npc)

func _remove_participant_from_fight(npc: NPC) -> void:
	target_mapping.erase(npc)
	fight_positions.erase(npc)
	last_attack.erase(npc)
	attack_intervals.erase(npc)
	pending_attacks.erase(npc)
	if opening_attacker == npc:
		opening_attacker = null
		opening_strike_resolved = true
	for attacker in target_mapping.keys().duplicate():
		if target_mapping[attacker] == npc:
			target_mapping.erase(attacker)
	for attacker in pending_attacks.keys().duplicate():
		var attack: Dictionary = pending_attacks[attacker]
		if attack.get("target", null) == npc:
			pending_attacks.erase(attacker)

	if npc.Navigation != null:
		npc.Navigation.stop_navigation()

func _should_convert_knockout_to_injury(target: NPC, target_energy_after_hit: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not InjuryHandler.is_injury_unlocked():
		return false
	if target_energy_after_hit > 0.0:
		return false
	if target.Status == null or target.Status.has_status(Enum.NpcStatus.INJURED):
		return false
	return randf() < INJURY_INSTEAD_OF_KO_CHANCE

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
		UiNotifications.update_npc_health_bar(health_bars[participant], participant.energy / participant.get_max_energy())

func _health_bar_color(npc: NPC) -> Color:
	if _is_law_side_participant(npc):
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
			if _is_law_side_participant(survivor):
				return Result.WORKERS_WON
			if survivor is NPCGuest:
				return Result.NO_CONTEST
		return Result.NO_CONTEST

	var has_active_worker := false
	var has_active_guest := false
	for participant: NPC in active_participants:
		if _is_law_side_participant(participant):
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
		if not is_instance_valid(participant):
			continue
		var guest := participant as NPCGuest
		if not is_instance_valid(guest):
			continue
		if not _should_apply_worker_win_to_guest(guest):
			_debug("worker win skip %s reason=%s" % [_npc_debug(guest), _join_reason_name(guest)])
			continue
		_debug("worker win apply %s reason=%s" % [_npc_debug(guest), _join_reason_name(guest)])
		if fight_type == FightType.BRAWL and guest.look_info != null:
			BountyHandler.create_fight_fine(guest, Pricing.DRUNK_FIGHT_FINE)
		ConflictResponseHandler.unmark_for_arrest(guest)
		var is_injured := (guest.Status != null and guest.Status.has_status(Enum.NpcStatus.INJURED))
		var prev_b := guest.Behaviour.behaviour_instance
		print("[Fight] Workers won — arresting guest injured=%s prev_behaviour=%s" % [
			is_injured,
			prev_b.get_script().resource_path.get_file() if prev_b != null else "null"
		])
		guest.force_behaviour(ArrestedBehaviour)

func _should_apply_worker_win_to_guest(guest: NPCGuest) -> bool:
	var behaviour = guest.Behaviour.behaviour_instance
	if not (behaviour is FightBehaviour or behaviour is KnockedOutBehaviour):
		return false
	if fight_type == FightType.BRAWL:
		return did_participant_start_brawl(guest)
	return true

func _is_law_side_participant(npc: NPC) -> bool:
	if npc is NPCWorker:
		return true
	var join_reason := int(participant_join_reasons.get(npc, JoinReason.UNKNOWN))
	return (
		join_reason == JoinReason.WORKER_RESPONSE
		or join_reason == JoinReason.ARREST_RESPONSE
		or join_reason == JoinReason.ROBBERY_RESPONSE
	)

func _join_reason_name(npc: NPC) -> String:
	return JoinReason.keys()[int(participant_join_reasons.get(npc, JoinReason.UNKNOWN))]

func _cleanup_inactive_participants(active_participants: Array) -> void:
	for i: int in range(participants.size() - 1, -1, -1):
		var participant = participants[i]
		if not is_instance_valid(participant):
			participants.remove_at(i)
			participant_join_reasons.erase(participant)
			target_mapping.erase(participant)
			last_attack.erase(participant)
			attack_intervals.erase(participant)
			pending_attacks.erase(participant)
			fight_positions.erase(participant)
			continue
		var participant_npc := participant as NPC
		if participant_npc == null:
			participants.remove_at(i)
			participant_join_reasons.erase(participant)
			target_mapping.erase(participant)
			last_attack.erase(participant)
			attack_intervals.erase(participant)
			pending_attacks.erase(participant)
			fight_positions.erase(participant)

	for participant in target_mapping.keys():
		if not is_instance_valid(participant):
			target_mapping.erase(participant)
			continue
		var target = target_mapping[participant]
		if not is_instance_valid(target):
			target_mapping.erase(participant)
			continue
		var target_npc := target as NPC
		if target_npc == null:
			target_mapping.erase(participant)
			continue
		if not active_participants.has(participant) or not active_participants.has(target):
			target_mapping.erase(participant)

	for participant in last_attack.keys().duplicate():
		if not is_instance_valid(participant) or not active_participants.has(participant):
			last_attack.erase(participant)

	for participant in attack_intervals.keys().duplicate():
		if not is_instance_valid(participant) or not active_participants.has(participant):
			attack_intervals.erase(participant)

	for participant in pending_attacks.keys().duplicate():
		if not is_instance_valid(participant) or not active_participants.has(participant):
			pending_attacks.erase(participant)
			continue
		var attack: Dictionary = pending_attacks[participant]
		var target = attack.get("target", null)
		if not is_instance_valid(target) or not active_participants.has(target):
			pending_attacks.erase(participant)

	for participant in fight_positions.keys():
		if not is_instance_valid(participant) or not active_participants.has(participant):
			fight_positions.erase(participant)

	for participant in participant_join_reasons.keys():
		if not is_instance_valid(participant):
			participant_join_reasons.erase(participant)

func _get_fight_behaviour(npc: NPC) -> FightBehaviour:
	if npc == null or not is_instance_valid(npc) or npc.Behaviour == null:
		return null
	return npc.Behaviour.behaviour_instance as FightBehaviour
