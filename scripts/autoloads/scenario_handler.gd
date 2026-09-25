extends Node

## Runtime driver for the scenario configuration system (sandbox presets and
## campaigns). Never acts on its own in _ready()/_process() until a scenario
## is explicitly started - StartupCoordinator.begin() is the only caller that
## decides whether the hardcoded tutorial or a queued scenario runs.

enum WinState {
	NONE,
	WON,
	LOST,
}

const SCENARIOS_DIR := "res://assets/resources/scenarios/"
const EVALUATE_INTERVAL := 2.0
const CAMPAIGN_PROGRESS_PATH := "user://campaign_progress.json"

signal scenario_won_signal
signal scenario_lost_signal

var current_scenario: ScenarioData
var pending_scenario: ScenarioData
var win_state: int = WinState.NONE
var active_story_beats: Array[Dictionary] = []

var _registered_quest_keys: Array[String] = []
var _goal_conditions: Dictionary = {}
var _win_conditions: Array[Dictionary] = []
var _lose_conditions: Array[Dictionary] = []
var _registry: Dictionary = {}
var _registry_built := false
var _evaluate_accum := 0.0
var _solved_campaign_ids: Dictionary = {}


func _ready() -> void:
	Console.add_command("start_scenario", _console_start_scenario, ["id"], 1, "Starts a registered scenario by id directly, skipping the tutorial.")
	Console.add_command("list_scenarios", _console_list_scenarios, 0, 0, "Lists every registered scenario id.")
	Console.add_command("scenario_status", _console_scenario_status, 0, 0, "Prints the active scenario id, win state, and goal phases.")
	Console.add_command("force_win", _console_force_win, 0, 0, "Forces the active campaign scenario into the WON state.")
	Console.add_command("force_lose", _console_force_lose, 0, 0, "Forces the active campaign scenario into the LOST state.")
	Console.add_command("solved_campaigns", _console_solved_campaigns, 0, 0, "Lists campaign scenario ids marked as solved.")
	_load_campaign_progress()


func _process(delta: float) -> void:
	if current_scenario == null or not is_campaign_active():
		return
	_evaluate_accum += delta
	if _evaluate_accum < EVALUATE_INTERVAL:
		return
	_evaluate_accum = 0.0
	evaluate_conditions()


func queue_scenario(scenario: ScenarioData) -> void:
	pending_scenario = scenario


func end_session() -> void:
	current_scenario = null
	pending_scenario = null
	win_state = WinState.NONE
	active_story_beats.clear()
	_registered_quest_keys.clear()
	_goal_conditions.clear()
	_win_conditions.clear()
	_lose_conditions.clear()
	_evaluate_accum = 0.0


func start_scenario(scenario: ScenarioData) -> void:
	current_scenario = scenario
	Balancing.GUEST_SPAWN_BASE_RATE = scenario.guest_spawn_base_rate
	win_state = WinState.NONE
	_registered_quest_keys.clear()
	active_story_beats.clear()
	_goal_conditions.clear()
	_win_conditions.clear()
	_lose_conditions.clear()
	_evaluate_accum = 0.0

	MoneyHandler.set_starting_money(scenario.starting_money)

	if scenario.use_default_starting_layout:
		StartupCoordinator.setup_building()
	else:
		_apply_custom_starting_rooms(scenario.starting_rooms)

	if scenario.use_default_unlocks:
		ProgressionHandler.unlock_default_rooms()
	else:
		_force_unlock_rooms(scenario.unlocked_rooms)

	for feature in scenario.feature_overrides:
		FeatureGateHandler.set_enabled(feature as FeatureGateHandler.Feature, bool(scenario.feature_overrides[feature]))

	if is_instance_valid(Global.NPCSpawner):
		Global.NPCSpawner.robber_spawn_chance = scenario.robber_spawn_chance

	StartupCoordinator.spawn_bounties(scenario.starting_bounty_count)
	for stack: ScenarioItemStack in scenario.starting_item_stacks:
		StartupCoordinator.spawn_item_stack(stack.item_type, stack.room_x, stack.room_y, stack.amount)

	for _i in scenario.starting_worker_count:
		Global.NPCSpawner.spawn_new_worker()
	for _i in scenario.starting_guest_count:
		Global.NPCSpawner.spawn_new_guest()

	if Global.UI != null and Global.UI.controls != null:
		Global.UI.controls.visible = scenario.show_basic_controls_ui

	if scenario is CampaignScenarioData:
		_start_campaign(scenario as CampaignScenarioData)


func resume_scenario(scenario: ScenarioData, saved_win_state: int) -> void:
	current_scenario = scenario
	Balancing.GUEST_SPAWN_BASE_RATE = scenario.guest_spawn_base_rate
	win_state = saved_win_state
	_registered_quest_keys.clear()
	active_story_beats.clear()
	_goal_conditions.clear()
	_win_conditions.clear()
	_lose_conditions.clear()
	_evaluate_accum = 0.0

	if Global.UI != null and Global.UI.controls != null:
		Global.UI.controls.visible = scenario.show_basic_controls_ui

	if scenario is CampaignScenarioData:
		var campaign := scenario as CampaignScenarioData
		for goal: ScenarioGoalDefinition in campaign.goal_definitions:
			_registered_quest_keys.append(goal.key)
		_load_campaign_conditions(campaign)


func mark_beat_fired(beat_id: String) -> void:
	for beat in active_story_beats:
		if str(beat.get("id", "")) == beat_id:
			beat["fired"] = true


func get_fired_beat_ids() -> Array[String]:
	var ids: Array[String] = []
	for beat in active_story_beats:
		if beat.get("fired", false):
			ids.append(str(beat.get("id", "")))
	return ids


func get_registered_quest_keys() -> Array[String]:
	return _registered_quest_keys.duplicate()


func evaluate_conditions() -> void:
	if current_scenario == null or not is_campaign_active() or win_state != WinState.NONE:
		return

	var campaign := current_scenario as CampaignScenarioData
	for goal: ScenarioGoalDefinition in campaign.goal_definitions:
		var condition: Callable = _goal_conditions.get(goal.key, Callable())
		if not condition.is_valid():
			continue
		var quest := TutorialHandler.get_quest(goal.key)
		if quest == null or quest.is_done:
			continue
		if condition.call():
			quest.set_done()

	for beat in active_story_beats:
		if beat.get("fired", false):
			continue
		var trigger: Callable = beat.get("trigger_condition", Callable())
		if not trigger.is_valid() or not trigger.call():
			continue
		beat["fired"] = true
		_run_story_beat(beat)

	for lose_entry: Dictionary in _lose_conditions:
		var lose_condition: Callable = lose_entry.get("condition", Callable())
		if lose_condition.is_valid() and lose_condition.call():
			_set_win_state(WinState.LOST)
			return

	for win_entry: Dictionary in _win_conditions:
		var win_condition: Callable = win_entry.get("condition", Callable())
		if win_condition.is_valid() and win_condition.call():
			_set_win_state(WinState.WON)
			return


func get_current_scenario() -> ScenarioData:
	return current_scenario


func get_win_condition_descriptions() -> Array[String]:
	var descriptions: Array[String] = []
	for entry: Dictionary in _win_conditions:
		descriptions.append(str(entry.get("description", "")))
	return descriptions


func get_lose_condition_descriptions() -> Array[String]:
	var descriptions: Array[String] = []
	for entry: Dictionary in _lose_conditions:
		descriptions.append(str(entry.get("description", "")))
	return descriptions


func is_campaign_active() -> bool:
	return current_scenario is CampaignScenarioData and win_state == WinState.NONE


## Empty allowed_npc_archetypes on the active scenario (or no active
## scenario, e.g. the default tutorial path) means unrestricted.
func is_archetype_allowed(body_type: int) -> bool:
	if current_scenario == null or current_scenario.allowed_npc_archetypes.is_empty():
		return true
	var archetype = NPCArchetypeLibrary.get_archetype(body_type)
	return current_scenario.allowed_npc_archetypes.has(archetype)


func get_scenario(id: String) -> ScenarioData:
	_ensure_registry()
	return _registry.get(id, null)


func get_registered_scenario_ids() -> Array[String]:
	_ensure_registry()
	var ids: Array[String] = []
	for id in _registry.keys():
		ids.append(id)
	return ids


func _start_campaign(campaign: CampaignScenarioData) -> void:
	for goal: ScenarioGoalDefinition in campaign.goal_definitions:
		_registered_quest_keys.append(goal.key)
		var quest := TutorialHandler.create_quest(goal.key, goal.text, [], goal.reward_money, goal.reward_text, TutorialHandler.TutorialPhase.ACTIVE)
		quest.start()
	_load_campaign_conditions(campaign)


func _load_campaign_conditions(campaign: CampaignScenarioData) -> void:
	if campaign.conditions_script != null:
		var conditions = campaign.conditions_script.new()
		if conditions.has_method("get_goal_conditions"):
			_goal_conditions = conditions.get_goal_conditions()
		if conditions.has_method("get_win_conditions"):
			_win_conditions = conditions.get_win_conditions()
		if conditions.has_method("get_lose_conditions"):
			_lose_conditions = conditions.get_lose_conditions()

	if campaign.story_beat_script != null:
		var beat_source = campaign.story_beat_script.new()
		for entry: Dictionary in beat_source.load_entries():
			var beat: Dictionary = entry.duplicate(true)
			beat["fired"] = false
			active_story_beats.append(beat)


func _run_story_beat(beat: Dictionary) -> void:
	if Global.UI == null or Global.UI.encounter == null:
		return
	var choice: Dictionary = await Global.UI.encounter.start_encounter(Building, beat)
	var effects: Array = choice.get("effects", [])
	for effect: Callable in effects:
		if effect.is_valid():
			effect.call()
	var outcome_text := str(choice.get("outcome_text", ""))
	if outcome_text != "":
		await Global.UI.encounter.show_outcome(Building, outcome_text)
	else:
		Global.UI.encounter.close_encounter()


func _set_win_state(new_state: int) -> void:
	if win_state != WinState.NONE:
		return
	win_state = new_state
	if new_state == WinState.WON:
		if current_scenario != null and not current_scenario.scenario_id.is_empty():
			_mark_campaign_solved(current_scenario.scenario_id)
		scenario_won_signal.emit()
	elif new_state == WinState.LOST:
		scenario_lost_signal.emit()


func is_campaign_solved(id: String) -> bool:
	return _solved_campaign_ids.has(id)


func get_solved_campaign_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _solved_campaign_ids.keys():
		ids.append(id)
	return ids


func _mark_campaign_solved(id: String) -> void:
	if _solved_campaign_ids.has(id):
		return
	_solved_campaign_ids[id] = true
	_save_campaign_progress()


func _load_campaign_progress() -> void:
	_solved_campaign_ids.clear()
	if not FileAccess.file_exists(CAMPAIGN_PROGRESS_PATH):
		return
	var file := FileAccess.open(CAMPAIGN_PROGRESS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("solved_campaign_ids"):
		for id in parsed["solved_campaign_ids"]:
			_solved_campaign_ids[str(id)] = true


func _save_campaign_progress() -> void:
	var file := FileAccess.open(CAMPAIGN_PROGRESS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"solved_campaign_ids": get_solved_campaign_ids()}))
	file.close()


func _apply_custom_starting_rooms(placements: Array[ScenarioRoomPlacement]) -> void:
	for placement: ScenarioRoomPlacement in placements:
		if placement.room_data == null:
			continue
		Building.set_room(placement.room_data, placement.x, placement.y, false)
	Building.initialize_all_rooms()
	Building.update_foreground_tiles()


func _force_unlock_rooms(rooms: Array[RoomData]) -> void:
	for room: RoomData in rooms:
		var item := ProgressionHandler.get_item_for_room(room)
		if item != null:
			ProgressionHandler.force_unlock(item)


func _ensure_registry() -> void:
	if _registry_built:
		return
	_registry_built = true
	_registry.clear()

	var dir := DirAccess.open(SCENARIOS_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var scenario := load(SCENARIOS_DIR + file_name) as ScenarioData
			if scenario != null:
				var key := scenario.scenario_id if not scenario.scenario_id.is_empty() else file_name.get_basename()
				_registry[key] = scenario
		file_name = dir.get_next()
	dir.list_dir_end()


func _console_start_scenario(id: String) -> void:
	var scenario := get_scenario(id)
	if scenario == null:
		Console.print_error("Unknown scenario id '%s'." % id)
		return
	start_scenario(scenario)
	Console.print_line("Started scenario '%s'." % id)


func _console_list_scenarios() -> void:
	var ids := get_registered_scenario_ids()
	if ids.is_empty():
		Console.print_line("No scenarios registered.")
		return
	for id in ids:
		Console.print_line(id)


func _console_scenario_status() -> void:
	if current_scenario == null:
		Console.print_line("No active scenario.")
		return

	Console.print_line("scenario_id = %s" % current_scenario.scenario_id)
	Console.print_line("win_state = %s" % WinState.keys()[win_state])

	if current_scenario is CampaignScenarioData:
		for goal: ScenarioGoalDefinition in (current_scenario as CampaignScenarioData).goal_definitions:
			var quest := TutorialHandler.get_quest(goal.key)
			var phase_name: String = TutorialHandler.TutorialPhase.keys()[quest.phase] if quest != null else "DONE"
			Console.print_line("goal %s: %s" % [goal.key, phase_name])


func _console_force_win() -> void:
	_set_win_state(WinState.WON)
	Console.print_line("win_state = %s" % WinState.keys()[win_state])


func _console_force_lose() -> void:
	_set_win_state(WinState.LOST)
	Console.print_line("win_state = %s" % WinState.keys()[win_state])


func _console_solved_campaigns() -> void:
	var ids := get_solved_campaign_ids()
	if ids.is_empty():
		Console.print_line("No campaigns solved yet.")
		return
	for id in ids:
		Console.print_line(id)
