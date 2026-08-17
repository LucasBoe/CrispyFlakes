extends Control
class_name SandboxConfigMenu

signal start_requested(scenario: ScenarioData)

const DEFAULT_SCENARIO_PATH := "res://assets/resources/scenarios/scenario_sandbox_default.tres"

@onready var money_spinbox: SpinBox = $MarginContainer/MarginContainer/GridContainer/MoneySpinBox
@onready var bounty_spinbox: SpinBox = $MarginContainer/MarginContainer/GridContainer/BountySpinBox
@onready var worker_spinbox: SpinBox = $MarginContainer/MarginContainer/GridContainer/WorkerSpinBox
@onready var guest_spinbox: SpinBox = $MarginContainer/MarginContainer/GridContainer/GuestSpinBox
@onready var robber_checkbox: CheckBox = $MarginContainer/MarginContainer/GridContainer/RobberCheckBox
@onready var robber_slider: HSlider = $MarginContainer/MarginContainer/GridContainer/RobberSlider
@onready var guest_auto_spawn_checkbox: CheckBox = $MarginContainer/MarginContainer/GridContainer/GuestAutoSpawnCheckBox
@onready var injury_checkbox: CheckBox = $MarginContainer/MarginContainer/GridContainer/InjuryCheckBox
@onready var temperature_checkbox: CheckBox = $MarginContainer/MarginContainer/GridContainer/TemperatureCheckBox
@onready var special_encounters_checkbox: CheckBox = $MarginContainer/MarginContainer/GridContainer/SpecialEncountersCheckBox
@onready var start_button: Button = $MarginContainer/MarginContainer/GridContainer/ButtonRow/StartButton
@onready var back_button: Button = $MarginContainer/MarginContainer/GridContainer/ButtonRow/BackButton

var _default_scenario: ScenarioData

func _ready() -> void:
	_default_scenario = load(DEFAULT_SCENARIO_PATH) as ScenarioData
	_apply_defaults()
	robber_checkbox.toggled.connect(_on_robber_toggled)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _apply_defaults() -> void:
	if _default_scenario == null:
		return
	money_spinbox.value = _default_scenario.starting_money
	bounty_spinbox.value = _default_scenario.starting_bounty_count
	worker_spinbox.value = _default_scenario.starting_worker_count
	guest_spinbox.value = _default_scenario.starting_guest_count
	robber_slider.value = _default_scenario.robber_spawn_chance
	robber_checkbox.button_pressed = bool(_default_scenario.feature_overrides.get(FeatureGateHandler.Feature.ROBBER_SPAWN, FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.ROBBER_SPAWN)))
	guest_auto_spawn_checkbox.button_pressed = bool(_default_scenario.feature_overrides.get(FeatureGateHandler.Feature.GUEST_AUTO_SPAWN, true))
	injury_checkbox.button_pressed = bool(_default_scenario.feature_overrides.get(FeatureGateHandler.Feature.INJURY_SYSTEM, FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.INJURY_SYSTEM)))
	temperature_checkbox.button_pressed = bool(_default_scenario.feature_overrides.get(FeatureGateHandler.Feature.TEMPERATURE_SYSTEM, FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.TEMPERATURE_SYSTEM)))
	special_encounters_checkbox.button_pressed = bool(_default_scenario.feature_overrides.get(FeatureGateHandler.Feature.SPECIAL_ENCOUNTERS, FeatureGateHandler.is_enabled(FeatureGateHandler.Feature.SPECIAL_ENCOUNTERS)))
	robber_slider.editable = robber_checkbox.button_pressed

func _on_robber_toggled(pressed: bool) -> void:
	robber_slider.editable = pressed

func _on_start_pressed() -> void:
	var scenario := ScenarioData.new()
	scenario.scenario_id = "scenario_sandbox_custom"
	scenario.display_name = "Sandbox"
	scenario.description = "Custom sandbox run."
	scenario.starting_money = int(money_spinbox.value)
	scenario.starting_bounty_count = int(bounty_spinbox.value)
	scenario.starting_worker_count = int(worker_spinbox.value)
	scenario.starting_guest_count = int(guest_spinbox.value)
	scenario.use_default_starting_layout = true
	scenario.use_default_unlocks = true
	scenario.robber_spawn_chance = robber_slider.value
	scenario.feature_overrides = {
		FeatureGateHandler.Feature.ROBBER_SPAWN: robber_checkbox.button_pressed,
		FeatureGateHandler.Feature.GUEST_AUTO_SPAWN: guest_auto_spawn_checkbox.button_pressed,
		FeatureGateHandler.Feature.INJURY_SYSTEM: injury_checkbox.button_pressed,
		FeatureGateHandler.Feature.TEMPERATURE_SYSTEM: temperature_checkbox.button_pressed,
		FeatureGateHandler.Feature.SPECIAL_ENCOUNTERS: special_encounters_checkbox.button_pressed,
	}
	scenario.is_campaign = false
	scenario.show_basic_controls_ui = _default_scenario.show_basic_controls_ui if _default_scenario != null else false
	start_requested.emit(scenario)

func _on_back_pressed() -> void:
	hide()
