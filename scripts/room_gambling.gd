extends RoomBase
class_name RoomGambling

const MATCH_COUNT := 10
const MAX_GUEST_COUNT := 3
const MATCH_DURATION := 8.0
const JACKPOT_OPTIONS: Array[int] = [20, 50, 100, 250, 500, 1000]
const CHEAT_FEE_MULTIPLIER := 3.0
const BASE_CHEAT_CHANCE := 0.04
const DRUNK_CHEAT_CHANCE := 0.08
const BASE_WATCHER_DETECTION_CHANCE := 0.65

var guests: Dictionary = {}
var max_guest_count: int = MAX_GUEST_COUNT
var active_round: bool = false
var loop_enabled: bool = false
var selected_jackpot: int = 0
var matches_played: int = 0
var current_match_progress: float = 0.0
var remaining_money_pool: float = 0.0
var participants: Array[NPCGuest] = []
var last_summary: Dictionary = {}
var _round_running: bool = false

func init_room(_x: int, _y: int):
	associated_job = Enum.Jobs.GAMBLING_WATCHER
	super.init_room(_x, _y)

	for i in max_guest_count:
		guests[i] = null

func is_free() -> bool:
	return can_join_round()

func get_free_count() -> int:
	var c: int = 0
	for i in max_guest_count:
		if guests[i] == null:
			c += 1
	return c

func can_join_round() -> bool:
	return active_round and matches_played < MATCH_COUNT and get_free_count() > 0

func has_active_round() -> bool:
	return active_round

func can_delete() -> bool:
	return not active_round

func can_accept_worker(job = null) -> bool:
	if job == null:
		job = associated_job
	return job == associated_job and worker == null

func get_job_capacity(job = null) -> int:
	if job == null:
		job = associated_job
	return 1 if job == associated_job else 0

func get_assigned_worker_count(job = null) -> int:
	if job == null:
		job = associated_job
	return 1 if job == associated_job and worker != null else 0

func sit(guest: NPC) -> Vector2:
	if not can_join_round() or guest is not NPCGuest:
		return get_random_floor_position()

	var guest_ref := guest as NPCGuest
	for i in max_guest_count:
		if guests[i] == null:
			guests[i] = guest_ref
			break

	if not participants.has(guest_ref):
		participants.append(guest_ref)
		_collect_guest_stake(guest_ref)

	guest_ref.Animator.set_sitting(true)
	guest_ref.Animator.set_z(Enum.ZLayer.NPC_BEHIND_CONTENT)

	show_guest_count_notification()

	return get_random_floor_position()

func is_guest_in_round(guest: NPCGuest) -> bool:
	return participants.has(guest)

func is_guest_seated(guest: NPC) -> bool:
	return guests.values().has(guest)

func stand_up(guest: NPC) -> void:
	guest.Animator.set_sitting(false)
	guest.Animator.set_z(Enum.ZLayer.NPC_DEFAULT)
	for i in max_guest_count:
		if guests[i] == guest:
			guests[i] = null
	participants.erase(guest)

	show_guest_count_notification()

func show_guest_count_notification() -> void:
	var free: int = get_free_count()
	var txt: String = str(max_guest_count - free, "/", max_guest_count)
	UiNotifications.create_notification_static(txt, get_center_position(), null, Color.BLACK if free > 0 else Color.RED)

func start_round(jackpot: int) -> bool:
	if active_round or jackpot <= 0:
		return false
	if not ResourceHandler.has_money(jackpot):
		UiNotifications.create_notification_static("not enough money", get_notification_position(), null, Color.ORANGE)
		return false

	selected_jackpot = jackpot
	matches_played = 0
	remaining_money_pool = jackpot
	participants.clear()
	last_summary = _new_summary(jackpot)
	active_round = true
	_round_running = true
	ResourceHandler.spend_animated(jackpot, get_center_position())
	_run_round()
	return true

func set_loop_enabled(enabled: bool) -> void:
	loop_enabled = enabled

func assign_watcher(npc: NPCWorker) -> bool:
	if npc == null or worker != null:
		return false
	worker = npc
	return true

func remove_watcher(npc: NPCWorker) -> void:
	if worker == npc:
		worker = null

func get_watcher_position() -> Vector2:
	return global_position + Vector2(24, -12)

func get_per_match_stake() -> float:
	if selected_jackpot <= 0:
		return 0.0
	return float(selected_jackpot) / float(MATCH_COUNT)

func get_estimated_revenue(jackpot: int) -> Dictionary:
	return {
		worst = -jackpot,
		best = jackpot * max_guest_count,
	}

func get_round_status_text() -> String:
	if active_round:
		if participants.is_empty():
			return "Waiting for Players (%d/%d)" % [matches_played, MATCH_COUNT]
		return "Round in Progress (%d/%d)" % [matches_played, MATCH_COUNT]
	if not last_summary.is_empty():
		return "Last Round Summary"
	return "No Round"

func get_round_progress() -> float:
	return current_match_progress

func get_ui_state_signature() -> String:
	return "%s|%s|%d|%d|%d|%d|%d|%d|%s|%d" % [
		str(active_round),
		str(loop_enabled),
		selected_jackpot,
		matches_played,
		roundi(current_match_progress * 100.0),
		roundi(remaining_money_pool),
		participants.size(),
		get_assigned_worker_count(),
		str(last_summary),
		roundi(MoneyHandler.get_money_at(Vector2i(x, y))),
	]

func _run_round() -> void:
	while active_round and matches_played < MATCH_COUNT:
		if _get_live_participants().is_empty():
			current_match_progress = 0.0
			await get_tree().create_timer(0.5).timeout
			continue

		await _progress_match_timer()
		if not active_round:
			return
		_play_match()

	_finish_round()

func _play_match() -> void:
	var live_participants := _get_live_participants()
	if live_participants.is_empty():
		return

	var match_pool_amount := _take_next_match_pool_amount()
	if match_pool_amount <= 0.0:
		return

	var normal_winner = null
	if randi_range(0, live_participants.size()) > 0:
		normal_winner = live_participants.pick_random()

	var final_winner = normal_winner
	for guest in live_participants:
		if guest == normal_winner:
			continue
		if randf() > _get_cheat_chance(guest):
			continue
		if _watcher_detects_cheat():
			var fee := roundi(match_pool_amount * CHEAT_FEE_MULTIPLIER)
			last_summary.detected_cheats += 1
			last_summary.cheating_fees += fee
			UiNotifications.create_notification_static("+%d$ fee" % fee, get_notification_position(), null, Color.GREEN)
		else:
			last_summary.successful_cheats += 1
			final_winner = guest
			break

	matches_played += 1
	if final_winner == null:
		last_summary.bank_wins += 1
		last_summary.bank_stake_returns += match_pool_amount
		UiNotifications.create_notification_static("Bank wins", get_notification_position(), null, Color.GREEN)
	else:
		last_summary.player_wins += 1
		last_summary.player_payouts += match_pool_amount
		UiNotifications.create_notification_static("Player wins", get_notification_position(), null, Color.ORANGE)

func _finish_round() -> void:
	active_round = false
	_round_running = false
	current_match_progress = 0.0
	last_summary.revenue = _calculate_summary_revenue(last_summary)
	_apply_round_settlement(last_summary)

	for guest in participants.duplicate():
		if is_instance_valid(guest):
			guest.add_satisfaction(0.1, "Gambling")
			stand_up(guest)
	participants.clear()

	if not loop_enabled:
		if worker != null:
			worker.change_job(Enum.Jobs.IDLE)
		return

	await get_tree().create_timer(1.0).timeout
	if loop_enabled and is_instance_valid(self):
		start_round(selected_jackpot)

func _progress_match_timer() -> void:
	current_match_progress = 0.0
	var elapsed: float = 0.0
	while elapsed < MATCH_DURATION and active_round:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		current_match_progress = clampf(elapsed / MATCH_DURATION, 0.0, 1.0)
	current_match_progress = 1.0

func _apply_round_settlement(summary: Dictionary) -> void:
	var settlement: int = roundi(
		float(summary.bank_stake_returns)
		+ float(summary.cheating_fees)
	)
	if settlement > 0:
		ResourceHandler.add_animated(Enum.Resources.MONEY, settlement, get_center_position(), Vector2i(x, y))
	elif settlement < 0:
		ResourceHandler.spend_animated(-settlement, get_center_position())

func _collect_guest_stake(guest: NPCGuest) -> void:
	var stake: int = selected_jackpot
	if stake <= 0:
		return
	last_summary.player_stakes += stake
	last_summary.player_count += 1
	remaining_money_pool += stake
	UiNotifications.create_notification_static("+%d$ stake" % stake, get_notification_position(), null, Color.GREEN)

func _take_next_match_pool_amount() -> float:
	var remaining_matches: int = maxi(1, MATCH_COUNT - matches_played)
	var amount: float = remaining_money_pool / float(remaining_matches)
	remaining_money_pool = maxf(0.0, remaining_money_pool - amount)
	return amount

func _get_live_participants() -> Array[NPCGuest]:
	var live: Array[NPCGuest] = []
	for guest in participants.duplicate():
		if is_instance_valid(guest) and _is_guest_at_table(guest):
			live.append(guest)
		else:
			participants.erase(guest)
	return live

func _is_guest_at_table(guest: NPCGuest) -> bool:
	if not is_instance_valid(guest) or not is_guest_seated(guest):
		return false
	return Building.query.room_at_floor_position(guest.global_position) == self

func _get_cheat_chance(guest: NPCGuest) -> float:
	var drunkenness: float = guest.Needs.drunkenness.strength if guest.Needs != null else 0.0
	return clampf(BASE_CHEAT_CHANCE + drunkenness * DRUNK_CHEAT_CHANCE, 0.0, 0.18)

func _watcher_detects_cheat() -> bool:
	if worker == null:
		return false
	var multiplier: float = worker.Traits.get_criminal_detection_multiplier() if worker.Traits != null else 1.0
	return randf() < clampf(BASE_WATCHER_DETECTION_CHANCE * multiplier, 0.05, 0.95)

func _new_summary(jackpot: int) -> Dictionary:
	return {
		jackpot = jackpot,
		player_stakes = 0,
		player_count = 0,
		bank_stake_returns = 0.0,
		player_payouts = 0.0,
		gambling_revenue = 0.0,
		bank_wins = 0,
		player_wins = 0,
		detected_cheats = 0,
		successful_cheats = 0,
		cheating_fees = 0,
		revenue = 0.0,
	}

func _calculate_summary_revenue(summary: Dictionary) -> float:
	summary.gambling_revenue = -float(summary.jackpot) \
		+ float(summary.bank_stake_returns)
	return float(summary.gambling_revenue) + float(summary.cheating_fees)
