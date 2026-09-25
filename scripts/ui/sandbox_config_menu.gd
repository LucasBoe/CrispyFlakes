extends Control
class_name SandboxConfigMenu

signal start_requested(scenario: ScenarioData)
signal back_requested

const DEFAULT_SCENARIO_PATH := "res://assets/resources/scenarios/scenario_sandbox_default.tres"
const GRAYSCALE_SHADER := preload("res://assets/shaders/ui_grayscale.gdshader")

@onready var money_spinbox: SpinBox = %MoneySpinBox
@onready var bounty_spinbox: SpinBox = %BountySpinBox
@onready var worker_spinbox: SpinBox = %WorkerSpinBox
@onready var guest_spinbox: SpinBox = %GuestSpinBox
@onready var robber_checkbox: CheckBox = %RobberCheckBox
@onready var robber_slider: HSlider = %RobberSlider
@onready var robber_chance_value: Label = %RobberChanceValue
@onready var guest_auto_spawn_checkbox: CheckBox = %GuestAutoSpawnCheckBox
@onready var injury_checkbox: CheckBox = %InjuryCheckBox
@onready var temperature_checkbox: CheckBox = %TemperatureCheckBox
@onready var special_encounters_checkbox: CheckBox = %SpecialEncountersCheckBox
@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton
@onready var _archetype_cards: Dictionary = {
	1: %CowboyCard,
	2: %InvestorCard,
	3: %FarmerCard,
	4: %SettlerCard,
	5: %OutlawCard,
	6: %MinerCard,
}

@onready var _archetype_portraits: Dictionary = {
	1: %CowboyPortrait,
	2: %InvestorPortrait,
	3: %FarmerPortrait,
	4: %SettlerPortrait,
	5: %OutlawPortrait,
	6: %MinerPortrait,
}

## body_type -> checkbox, in the same order as NPCLookInfo.SPAWN_BODY_TYPES.
@onready var _archetype_checkboxes: Dictionary = {
	1: %ArchetypeCowboyCheckBox,
	2: %ArchetypeInvestorCheckBox,
	3: %ArchetypeFarmerCheckBox,
	4: %ArchetypeSettlerCheckBox,
	5: %ArchetypeOutlawCheckBox,
	6: %ArchetypeMinerCheckBox,
}

var _default_scenario: ScenarioData

const ACTIVE_CONTROL_MODULATE := Color.WHITE
const INACTIVE_CONTROL_MODULATE := Color(0.38, 0.38, 0.38, 1.0)
const FOCUS_CONTROL_MODULATE := Color(1.0, 0.5, 0.125, 1.0)

func _ready() -> void:
	for body_type: int in _archetype_checkboxes:
		var checkbox: CheckBox = _archetype_checkboxes[body_type]
		checkbox.toggled.connect(_on_archetype_toggled.bind(body_type))
		checkbox.focus_entered.connect(_refresh_archetype_cards)
		checkbox.focus_exited.connect(_refresh_archetype_cards)
		checkbox.mouse_entered.connect(_refresh_archetype_cards)
		checkbox.mouse_exited.connect(_refresh_archetype_cards.call_deferred)
		var card: PanelContainer = _archetype_cards[body_type]
		card.gui_input.connect(_on_archetype_card_input.bind(body_type))
		card.mouse_entered.connect(_refresh_archetype_cards)
		card.mouse_exited.connect(_refresh_archetype_cards.call_deferred)
	_default_scenario = load(DEFAULT_SCENARIO_PATH) as ScenarioData
	_apply_defaults()
	_refresh_archetype_cards()
	robber_checkbox.toggled.connect(_on_robber_toggled)
	robber_slider.value_changed.connect(_on_robber_chance_changed)
	robber_slider.focus_entered.connect(_on_robber_slider_focus_changed)
	robber_slider.focus_exited.connect(_on_robber_slider_focus_changed)
	_on_robber_chance_changed(robber_slider.value)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_configure_focus_order()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		money_spinbox.get_line_edit().grab_focus.call_deferred()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

func _configure_focus_order() -> void:
	var controls: Array[Control] = [
		money_spinbox.get_line_edit(), bounty_spinbox.get_line_edit(),
		worker_spinbox.get_line_edit(), guest_spinbox.get_line_edit(),
		robber_checkbox,
	]
	if robber_slider.editable:
		controls.append(robber_slider)
	controls.append_array([guest_auto_spawn_checkbox, injury_checkbox,
		temperature_checkbox, special_encounters_checkbox])
	for checkbox: CheckBox in _archetype_checkboxes.values():
		controls.append(checkbox)
	controls.append_array([back_button, start_button])
	for index in controls.size():
		var control := controls[index]
		control.focus_next = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(index - 1, controls.size())])

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
	_on_robber_toggled(robber_checkbox.button_pressed)

	var allowed := _default_scenario.allowed_npc_archetypes
	for body_type: int in _archetype_checkboxes:
		var checkbox: CheckBox = _archetype_checkboxes[body_type]
		checkbox.button_pressed = allowed.is_empty() or allowed.has(NPCArchetypeLibrary.get_archetype(body_type))

func _on_robber_toggled(pressed: bool) -> void:
	robber_slider.editable = pressed
	robber_slider.focus_mode = Control.FOCUS_ALL if pressed else Control.FOCUS_NONE
	_on_robber_slider_focus_changed()
	_configure_focus_order()

func _on_archetype_toggled(pressed: bool, body_type: int) -> void:
	_update_archetype_card(body_type, pressed)

func _on_archetype_card_input(event: InputEvent, body_type: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var checkbox: CheckBox = _archetype_checkboxes[body_type]
	if checkbox.get_global_rect().has_point(mouse_event.global_position):
		return
	checkbox.grab_focus()
	checkbox.button_pressed = not checkbox.button_pressed
	_archetype_cards[body_type].accept_event()

func _refresh_archetype_cards() -> void:
	for body_type: int in _archetype_checkboxes:
		var checkbox: CheckBox = _archetype_checkboxes[body_type]
		_update_archetype_card(body_type, checkbox.button_pressed)

func _update_archetype_card(body_type: int, selected: bool) -> void:
	var card: PanelContainer = _archetype_cards[body_type]
	var checkbox: CheckBox = _archetype_checkboxes[body_type]
	var portrait: TextureRect = _archetype_portraits[body_type]
	var content := card.get_child(0) as Control
	var highlighted := checkbox.has_focus() or card.get_global_rect().has_point(card.get_global_mouse_position())
	if highlighted:
		card.theme_type_variation = &"ArchetypeCardFocused"
	else:
		card.theme_type_variation = &"ArchetypeCardSelected" if selected else &"ArchetypeCard"
	var active := selected
	var tint := ACTIVE_CONTROL_MODULATE if active else INACTIVE_CONTROL_MODULATE
	content.modulate = Color.WHITE
	if active:
		portrait.material = null
		checkbox.material = null
	else:
		_apply_grayscale_material(portrait)
		_apply_grayscale_material(checkbox)
	checkbox.modulate = Color.WHITE
	portrait.modulate = Color.WHITE
	checkbox.add_theme_color_override("font_color", Color.WHITE)
	checkbox.add_theme_color_override("font_hover_color", Color.WHITE)
	checkbox.add_theme_color_override("font_focus_color", Color.WHITE)
	checkbox.add_theme_color_override("font_pressed_color", Color.WHITE)

func _apply_grayscale_material(control: Control) -> void:
	if control.material != null:
		return
	var grayscale_material := ShaderMaterial.new()
	grayscale_material.shader = GRAYSCALE_SHADER
	control.material = grayscale_material

func _on_robber_slider_focus_changed() -> void:
	var enabled := robber_slider.editable
	if not enabled:
		robber_chance_value.modulate = INACTIVE_CONTROL_MODULATE
		robber_slider.self_modulate = INACTIVE_CONTROL_MODULATE
		return
	robber_chance_value.modulate = ACTIVE_CONTROL_MODULATE
	robber_slider.self_modulate = ACTIVE_CONTROL_MODULATE

func _on_robber_chance_changed(value: float) -> void:
	robber_chance_value.text = "%d%%" % roundi(value * 100.0)

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

	var checked_archetypes: Array[NPCArchetype] = []
	var all_checked := true
	for body_type: int in _archetype_checkboxes:
		var checkbox: CheckBox = _archetype_checkboxes[body_type]
		if checkbox.button_pressed:
			checked_archetypes.append(NPCArchetypeLibrary.get_archetype(body_type))
		else:
			all_checked = false
	if all_checked:
		checked_archetypes.clear()
	scenario.allowed_npc_archetypes = checked_archetypes

	start_requested.emit(scenario)

func _on_back_pressed() -> void:
	back_requested.emit()
