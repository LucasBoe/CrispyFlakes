extends Control
class_name MainMenu

const GAMEPLAY_SCENE_PATH := "res://scenes/mainscene.tscn"
const CAMPAIGN_DEMO_SCENARIO_ID := "scenario_campaign_demo"

const MAIN_MENU_TWEEN_DURATION = .45

@export_range(0.0, 1.0, 0.01) var marker_move_duration := 0.18

@onready var continue_button: Button = %ContinueButton
@onready var _continue_title: Label = %ContinueButton/TitleLabel
@onready var _save_info_label: Label = %ContinueButton/SaveGameInfoLabel
@onready var new_game_button: Button = %NewGameButton
@onready var tutorial_button: Button = %TutorialButton
@onready var sandbox_button: Button = %SandboxButton
@onready var campaign_button: Button = %CampaignButton
@onready var quit_button: Button = %QuitButton
@onready var sandbox_config: SandboxConfigMenu = %SandboxConfig
@onready var campaign_selection: Control = %CampaignSelection
@onready var menu_camera: Camera2D = %Camera2D
@onready var menu_content: Control = %Content
@onready var selected_button_marker: Control = %SelectedButtonMarker
@onready var selected_button_arrow: TextureRect = %SelectedButtonArrow
@onready var _version_label: Label = $VersionLabel

var _selected_button: Button
var _continue_tween: Tween
var _marker_tween: Tween
var _arrow_tween: Tween
var _menu_buttons: Array[Button]
var _selected_arrow_base_x := 0.0
var _arrow_float_offset := 0.0:
	set(value):
		_arrow_float_offset = value
		selected_button_arrow.position.x = _selected_arrow_base_x + value
var _camera_home_position := Vector2.ZERO
var _transition_tween: Tween
var _menu_content_home_global_position := Vector2.ZERO

func _ready() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_version_label.text = "v%s" % version
	_version_label.visible = not version.is_empty()

	Building.visible = false
	continue_button.visible = SaveHandler.has_save()
	_setup_continue_info()
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	tutorial_button.pressed.connect(_on_new_game_pressed)
	sandbox_button.pressed.connect(_on_sandbox_pressed)
	campaign_button.pressed.connect(_on_campaign_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	sandbox_config.hide()
	campaign_selection.hide()
	sandbox_config.start_requested.connect(_on_sandbox_start_requested)
	sandbox_config.back_requested.connect(_on_sandbox_back_pressed)
	if campaign_selection.has_signal("back_requested"):
		campaign_selection.back_requested.connect(_on_campaign_back_pressed)
	_camera_home_position = menu_camera.position
	call_deferred("_capture_menu_content_home_position")

	# The marker overlays the buttons but must never intercept their input.
	selected_button_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control: Control in selected_button_marker.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_button_marker.hide()
	var menu_button_candidates: Array[Button] = [continue_button, new_game_button, tutorial_button, sandbox_button, campaign_button, quit_button]
	_menu_buttons.clear()
	for button: Button in menu_button_candidates:
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_entered.connect(_on_menu_button_hovered.bind(button))
		button.focus_entered.connect(_select_menu_button.bind(button))
		button.item_rect_changed.connect(_on_menu_button_rect_changed.bind(button))
		if button.visible and not button.disabled:
			_menu_buttons.append(button)
	_selected_arrow_base_x = selected_button_arrow.position.x
	_start_arrow_float()
	call_deferred("_focus_initial_button")

	Console.add_command("new_game", _on_new_game_pressed, 0, 0, "Starts a new default tutorial game from the main menu.")
	Console.add_command("start_scenario_from_menu", _console_start_scenario_from_menu, ["id"], 1, "Queues a scenario by id and transitions to gameplay, as if picked from the menu.")
	Console.add_command("continue_game", _on_continue_pressed, 0, 0, "Loads the existing save and transitions to gameplay, as if Continue was pressed.")

func _focus_initial_button() -> void:
	if _menu_buttons.is_empty():
		return
	_menu_buttons[0].grab_focus()
	_position_selected_marker(false)

func _capture_menu_content_home_position() -> void:
	_menu_content_home_global_position = menu_content.global_position
	menu_content.set_as_top_level(true)
	menu_content.global_position = _menu_content_home_global_position

func _on_menu_button_hovered(button: Button) -> void:
	if not _is_section_open() and not button.disabled:
		button.grab_focus()

func _select_menu_button(button: Button) -> void:
	if _selected_button != button:
		SoundPlayer.play_ui_hover()
	_selected_button = button
	_update_continue_selection(button == continue_button)
	_position_selected_marker(true)

func _setup_continue_info() -> void:
	# Keep the button's hit area while its separate title moves above the save details.
	continue_button.custom_minimum_size.x = continue_button.get_combined_minimum_size().x
	_continue_title.text = continue_button.text
	_continue_title.add_theme_font_override("font", continue_button.get_theme_font("font"))
	_continue_title.add_theme_font_size_override("font_size", continue_button.get_theme_font_size("font_size"))
	_continue_title.add_theme_color_override("font_color", continue_button.get_theme_color("font_color"))
	continue_button.text = ""
	_continue_title.show()
	_save_info_label.hide()
	_save_info_label.modulate.a = 0.0
	var info := SaveHandler.get_save_info()
	var parts := PackedStringArray()
	if not info.is_empty():
		var mode := str(info.game_mode)
		if not str(info.scenario_name).is_empty():
			mode += ": " + str(info.scenario_name)
		parts.append(mode)
		if not str(info.saloon_name).is_empty():
			parts.append(str(info.saloon_name))
		parts.append(str(info.date))
	_save_info_label.text = " · ".join(parts)
	continue_button.tooltip_text = _save_info_label.text

func _update_continue_selection(selected: bool) -> void:
	if _continue_tween != null:
		_continue_tween.kill()
	_continue_title.add_theme_color_override("font_color", continue_button.get_theme_color("font_focus_color" if selected else "font_color"))
	var reveal := selected and not _save_info_label.text.is_empty()
	if reveal:
		_save_info_label.show()
	_continue_tween = create_tween().set_parallel(true)
	_continue_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_continue_tween.tween_property(_continue_title, "position:y", -4.0 if reveal else 0.0, marker_move_duration)
	_continue_tween.tween_property(_save_info_label, "modulate:a", 1.0 if reveal else 0.0, marker_move_duration)
	if not reveal:
		_continue_tween.chain().tween_callback(_save_info_label.hide)

func _unhandled_input(event: InputEvent) -> void:
	if _is_section_open() or _menu_buttons.is_empty():
		return
	var direction := 0
	if event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_DOWN):
		direction = 1
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_UP):
		direction = -1
	if direction == 0:
		return
	get_viewport().set_input_as_handled()
	var current_index := _menu_buttons.find(_selected_button)
	if current_index < 0:
		current_index = 0
	var next_index := posmod(current_index + direction, _menu_buttons.size())
	_menu_buttons[next_index].grab_focus()

func _start_arrow_float() -> void:
	if selected_button_arrow == null:
		return
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(self, "_arrow_float_offset", -1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(self, "_arrow_float_offset", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_menu_button_rect_changed(button: Button) -> void:
	if button == _selected_button:
		call_deferred("_position_selected_marker", false)

func _position_selected_marker(animate: bool) -> void:
	if _selected_button == null or _is_section_open():
		return
	var button_rect := _selected_button.get_global_rect()
	var target := button_rect.get_center() - selected_button_marker.size * 0.5 - Vector2(0,1)
	# Keep the arrow just outside this button's left edge, independent of the divider width.
	_selected_arrow_base_x = button_rect.position.x - target.x - selected_button_arrow.size.x - 2.0
	selected_button_arrow.position.x = _selected_arrow_base_x + _arrow_float_offset
	if _marker_tween != null:
		_marker_tween.kill()
	var was_visible := selected_button_marker.visible
	selected_button_marker.show()
	if animate and was_visible and marker_move_duration > 0.0:
		_marker_tween = create_tween()
		_marker_tween.tween_property(selected_button_marker, "global_position", target, marker_move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		selected_button_marker.global_position = target

func _is_section_open() -> bool:
	return _transition_tween != null or sandbox_config.visible or campaign_selection.visible

func _on_continue_pressed() -> void:
	if not SaveHandler.has_save():
		return
	ScenarioHandler.queue_scenario(null)
	SaveHandler.flag_pending_load()
	_go_to_gameplay()

func _on_new_game_pressed() -> void:
	ScenarioHandler.queue_scenario(null)
	_go_to_gameplay()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_sandbox_pressed() -> void:
	_transition_section(sandbox_config, 1, true)

func _on_campaign_pressed() -> void:
	_transition_section(campaign_selection, -1, true)

func _on_campaign_back_pressed() -> void:
	_transition_section(campaign_selection, -1, false)

func _on_sandbox_back_pressed() -> void:
	_transition_section(sandbox_config, 1, false)

func _transition_section(section: Control, direction: int, entering: bool) -> void:
	if _transition_tween != null:
		return
	if entering and _is_section_open():
		return
	if not entering and not section.visible:
		return

	var width := get_viewport_rect().size.x
	var menu_away := _menu_content_home_global_position - Vector2(width * direction, 0)
	var camera_away := _camera_home_position + Vector2(width * (9.0 / 10.0) * direction / menu_camera.zoom.x, 0)
	if entering:
		section.position.x = width * direction
		section.show()
	else:
		menu_content.global_position = menu_away
		menu_content.show()
	selected_button_marker.hide()

	# One timeline keeps both pages a viewport apart and synchronized with the shorter camera pan.
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(menu_camera, "position", camera_away if entering else _camera_home_position, MAIN_MENU_TWEEN_DURATION)
	_transition_tween.tween_property(menu_content, "global_position", menu_away if entering else _menu_content_home_global_position, MAIN_MENU_TWEEN_DURATION)
	_transition_tween.tween_property(section, "position:x", 0.0 if entering else width * direction, MAIN_MENU_TWEEN_DURATION)
	_transition_tween.finished.connect(func() -> void:
		_transition_tween = null
		if entering:
			menu_content.hide()
			section.get_node("%BackButton").grab_focus()
		else:
			section.hide()
			if _selected_button != null:
				_selected_button.grab_focus()
				_position_selected_marker(false)
	)

func _on_sandbox_start_requested(scenario: ScenarioData) -> void:
	ScenarioHandler.queue_scenario(scenario)
	_go_to_gameplay()

func _console_start_scenario_from_menu(id: String) -> void:
	var scenario := ScenarioHandler.get_scenario(id)
	if scenario == null:
		Console.print_error("Unknown scenario id '%s'." % id)
		return
	ScenarioHandler.queue_scenario(scenario)
	_go_to_gameplay()

func _go_to_gameplay() -> void:
	get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
