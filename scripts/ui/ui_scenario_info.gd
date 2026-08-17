extends Control
class_name ScenarioInfoTab

const _FEATURES := [
	FeatureGateHandler.Feature.ROBBER_SPAWN,
	FeatureGateHandler.Feature.GUEST_AUTO_SPAWN,
	FeatureGateHandler.Feature.INJURY_SYSTEM,
	FeatureGateHandler.Feature.TEMPERATURE_SYSTEM,
	FeatureGateHandler.Feature.SPECIAL_ENCOUNTERS,
]

@onready var _no_scenario_label: Label = $MarginContainer/MarginContainer/NoScenarioLabel
@onready var _content: VBoxContainer = $MarginContainer/MarginContainer/Content
@onready var _title_label: Label = $MarginContainer/MarginContainer/Content/TitleLabel
@onready var _description_label: Label = $MarginContainer/MarginContainer/Content/DescriptionLabel
@onready var _params_label: Label = $MarginContainer/MarginContainer/Content/ParamsLabel
@onready var _goals_label: Label = $MarginContainer/MarginContainer/Content/GoalsLabel
@onready var _conditions_label: Label = $MarginContainer/MarginContainer/Content/ConditionsLabel

func _ready() -> void:
	TutorialHandler.quests_changed_signal.connect(_refresh)
	ScenarioHandler.scenario_won_signal.connect(_refresh)
	ScenarioHandler.scenario_lost_signal.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var scenario := ScenarioHandler.get_current_scenario()
	if scenario == null:
		_no_scenario_label.show()
		_content.hide()
		return

	_no_scenario_label.hide()
	_content.show()

	_title_label.text = scenario.display_name
	_description_label.text = scenario.description
	_params_label.text = _build_params_text(scenario)

	if scenario is CampaignScenarioData:
		_goals_label.show()
		_conditions_label.show()
		_goals_label.text = _build_goals_text(scenario as CampaignScenarioData)
		_conditions_label.text = _build_conditions_text()
	else:
		_goals_label.hide()
		_conditions_label.hide()

func _build_params_text(scenario: ScenarioData) -> String:
	var lines: Array[String] = []
	lines.append("Starting Money: %d$" % scenario.starting_money)
	lines.append("Starting Bounties: %d" % scenario.starting_bounty_count)
	lines.append("Starting Workers: %d" % scenario.starting_worker_count)
	lines.append("Starting Guests: %d" % scenario.starting_guest_count)
	lines.append("Robber Spawn Chance: %d%%" % roundi(scenario.robber_spawn_chance * 100.0))
	for feature in _FEATURES:
		var enabled: bool = bool(scenario.feature_overrides.get(feature, FeatureGateHandler.is_enabled(feature)))
		lines.append("%s: %s" % [FeatureGateHandler.get_feature_name(feature), "ON" if enabled else "OFF"])
	return "\n".join(lines)

func _build_goals_text(campaign: CampaignScenarioData) -> String:
	var lines: Array[String] = ["Goals:"]
	for goal: ScenarioGoalDefinition in campaign.goal_definitions:
		var quest := TutorialHandler.get_quest(goal.key)
		var phase_name: String = TutorialHandler.TutorialPhase.keys()[quest.phase] if quest != null else "DONE"
		lines.append("- %s (%s)" % [goal.title, phase_name])
	return "\n".join(lines)

func _build_conditions_text() -> String:
	var lines: Array[String] = []
	var win_state: int = ScenarioHandler.win_state
	lines.append("Status: %s" % ScenarioHandler.WinState.keys()[win_state])
	lines.append("Win Conditions:")
	for description in ScenarioHandler.get_win_condition_descriptions():
		lines.append("- %s" % description)
	var lose_descriptions := ScenarioHandler.get_lose_condition_descriptions()
	if not lose_descriptions.is_empty():
		lines.append("Lose Conditions:")
		for description in lose_descriptions:
			lines.append("- %s" % description)
	return "\n".join(lines)
