extends Control

signal back_requested
signal scenario_selected(scenario: ScenarioData)

const GAMEPLAY_SCENE_PATH := "res://scenes/mainscene.tscn"
const DEFAULT_SCENARIO_ID := "scenario_campaign_red_mesa"

const STAR_FULL := preload("res://assets/sprites/ui/2x/star_difficulty_full.png")
const STAR_HALF := preload("res://assets/sprites/ui/2x/star_difficulty_half.png")
const STAR_EMPTY := preload("res://assets/sprites/ui/2x/star_difficulty_empty.png")
const STAR_COUNT := 5

# only gates that have an icon are shown
const FEATURE_ICONS := {
	FeatureGateHandler.Feature.INJURY_SYSTEM: preload("res://assets/sprites/ui/icon_injured.png"),
	FeatureGateHandler.Feature.TEMPERATURE_SYSTEM: preload("res://assets/sprites/ui/icon_cold.png"),
	FeatureGateHandler.Feature.ROBBER_SPAWN: preload("res://assets/sprites/ui/icon_robbert.png"),
}
const DISABLED_FEATURE_MODULATE := Color(1.0, 1.0, 1.0, 0.34)

const DETAILS_PATH := "MarginContainer/HBoxContainer/DetailsContainer/Margin/Layout/Body/Details/"

@onready var back_button: Button = %BackButton
@onready var start_button: Button = %StartButton
@onready var scenario_list: VBoxContainer = %ScenarioList
@onready var name_label: Label = $MarginContainer/HBoxContainer/DetailsContainer/Margin/Layout/Header/Name
@onready var description_label: Label = $MarginContainer/HBoxContainer/DetailsContainer/Margin/Layout/Body/Description
@onready var stars_container: HBoxContainer = get_node(DETAILS_PATH + "HBoxContainerDifficulty/StarsHBoxContainer")
@onready var guests_container: HBoxContainer = get_node(DETAILS_PATH + "HBoxContainerGuestTypes/StarsHBoxContainer")
@onready var features_container: HBoxContainer = get_node(DETAILS_PATH + "HBoxContainerFeatures/StarsHBoxContainer")

var _selected_scenario: ScenarioData
var _scenario_button_group := ButtonGroup.new()

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_add_button_sounds(back_button)
	back_button.grab_focus()
	_build_scenario_buttons()

func _build_scenario_buttons() -> void:
	_clear(scenario_list)
	var scenarios: Array[ScenarioData] = []
	for id in ScenarioHandler.get_registered_scenario_ids():
		var scenario := ScenarioHandler.get_scenario(id)
		if scenario.is_campaign:
			scenarios.append(scenario)
	scenarios.sort_custom(func(a: ScenarioData, b: ScenarioData) -> bool:
		return a.difficulty < b.difficulty if a.difficulty != b.difficulty else a.display_name < b.display_name)

	var default_scenario := ScenarioHandler.get_scenario(DEFAULT_SCENARIO_ID)
	var to_select: ScenarioData = default_scenario if scenarios.has(default_scenario) else (scenarios[0] if not scenarios.is_empty() else null)
	for scenario in scenarios:
		var button := Button.new()
		button.text = scenario.display_name
		button.toggle_mode = true
		button.button_group = _scenario_button_group
		button.custom_minimum_size = Vector2(0, 26)
		button.pressed.connect(_select_scenario.bind(scenario))
		_add_button_sounds(button)
		scenario_list.add_child(button)
		if scenario == to_select:
			button.button_pressed = true
	_select_scenario(to_select)

func _add_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(SoundPlayer.play_ui_hover)
	button.focus_entered.connect(SoundPlayer.play_ui_hover)
	button.pressed.connect(SoundPlayer.play_ui_click_down)

func get_selected_scenario() -> ScenarioData:
	return _selected_scenario

func _select_scenario(scenario: ScenarioData) -> void:
	_selected_scenario = scenario
	start_button.disabled = scenario == null
	_populate(scenario)
	scenario_selected.emit(scenario)

func _populate(scenario: ScenarioData) -> void:
	if scenario == null:
		return
	name_label.text = scenario.display_name
	description_label.text = scenario.description
	_fill_stars(scenario.difficulty)
	_fill_guests(scenario.allowed_npc_archetypes)
	_fill_features(scenario)

func _fill_stars(difficulty: float) -> void:
	_clear(stars_container)
	var half_stars := roundi(clampf(difficulty, 0.0, STAR_COUNT) * 2.0)
	for index in STAR_COUNT:
		var texture: Texture2D = STAR_EMPTY
		if half_stars >= (index + 1) * 2:
			texture = STAR_FULL
		elif half_stars == index * 2 + 1:
			texture = STAR_HALF
		stars_container.add_child(_make_icon(texture))

func _fill_guests(archetypes: Array[NPCArchetype]) -> void:
	_clear(guests_container)
	for archetype in archetypes:
		if archetype != null and archetype.icon != null:
			guests_container.add_child(_make_icon(archetype.icon))

func _fill_features(scenario: ScenarioData) -> void:
	_clear(features_container)
	for feature in FEATURE_ICONS:
		var enabled := bool(scenario.feature_overrides.get(feature, FeatureGateHandler.is_enabled(feature)))
		var icon := _make_icon(FEATURE_ICONS[feature])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		if not enabled:
			icon.modulate = DISABLED_FEATURE_MODULATE
		features_container.add_child(icon)

func _make_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	return icon

func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _on_back_pressed() -> void:
	if get_parent() is Control and get_parent().name == "UIMainMenu":
		back_requested.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/mainmenuscene.tscn")

func _on_start_pressed() -> void:
	ScenarioHandler.queue_scenario(_selected_scenario)
	get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
