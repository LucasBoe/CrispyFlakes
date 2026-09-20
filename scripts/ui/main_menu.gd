extends Control
class_name MainMenu

const GAMEPLAY_SCENE_PATH := "res://scenes/mainscene.tscn"
const CAMPAIGN_DEMO_SCENARIO_ID := "scenario_campaign_demo"

@export_range(0.0, 1.0, 0.01) var marker_move_duration := 0.18

@onready var continue_button: Button = %ContinueButton
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

var _selected_button: Button
var _marker_tween: Tween
var _arrow_tween: Tween
var _menu_buttons: Array[Button]
var _selected_arrow_base_x := 0.0
var _camera_home_position := Vector2.ZERO
var _camera_tween: Tween
var _section_tween: Tween
var _menu_tween: Tween
var _menu_content_home_position := Vector2.ZERO
var _menu_content_home_global_position := Vector2.ZERO

func _ready() -> void:
	Building.visible = false
	continue_button.visible = SaveHandler.has_save()
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
	sandbox_config.visibility_changed.connect(_on_sandbox_visibility_changed)
	campaign_selection.visibility_changed.connect(_on_campaign_visibility_changed)
	if campaign_selection.has_signal("back_requested"):
		campaign_selection.back_requested.connect(_on_campaign_back_pressed)
	_camera_home_position = menu_camera.position
	_menu_content_home_position = menu_content.position
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
	_menu_content_home_position = menu_content.position
	_menu_content_home_global_position = menu_content.global_position
	menu_content.set_as_top_level(true)
	menu_content.global_position = _menu_content_home_global_position

func _on_menu_button_hovered(button: Button) -> void:
	if not sandbox_config.visible and not button.disabled:
		button.grab_focus()

func _select_menu_button(button: Button) -> void:
	if _selected_button != button:
		SoundPlayer.play_ui_hover()
	_selected_button = button
	_position_selected_marker(true)

func _unhandled_input(event: InputEvent) -> void:
	if sandbox_config.visible or campaign_selection.visible or _menu_buttons.is_empty():
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
	var base_x := _selected_arrow_base_x
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(selected_button_arrow, "position:x", base_x - 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrow_tween.tween_property(selected_button_arrow, "position:x", base_x + 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_menu_button_rect_changed(button: Button) -> void:
	if button == _selected_button:
		call_deferred("_position_selected_marker", false)

func _position_selected_marker(animate: bool) -> void:
	if _selected_button == null or sandbox_config.visible:
		return
	var target := _selected_button.get_global_rect().get_center() - selected_button_marker.size * 0.5 - Vector2(0,1)
	if _marker_tween != null:
		_marker_tween.kill()
	var was_visible := selected_button_marker.visible
	selected_button_marker.show()
	if animate and was_visible and marker_move_duration > 0.0:
		_marker_tween = create_tween()
		_marker_tween.tween_property(selected_button_marker, "global_position", target, marker_move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		selected_button_marker.global_position = target

func _on_sandbox_visibility_changed() -> void:
	if sandbox_config.visible or campaign_selection.visible:
		selected_button_marker.hide()
		if sandbox_config.visible:
			_animate_section_in(sandbox_config, 1)
			_pan_camera(1)
	elif _selected_button != null:
		_pan_camera(0)
		_selected_button.grab_focus()
		_position_selected_marker(false)

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
	_animate_menu_out(-1)
	sandbox_config.show()
	_pan_camera(1)

func _on_campaign_pressed() -> void:
	_animate_menu_out(1)
	campaign_selection.show()
	_pan_camera(-1)

func _on_campaign_back_pressed() -> void:
	_animate_section_out(campaign_selection, -1, func() -> void:
		campaign_selection.hide()
		_pan_camera(0)
		_animate_menu_in(1)
	)

func _on_sandbox_back_pressed() -> void:
	_animate_section_out(sandbox_config, 1, func() -> void:
		sandbox_config.hide()
		_pan_camera(0)
		_animate_menu_in(-1)
	)

func _on_campaign_visibility_changed() -> void:
	selected_button_marker.visible = not sandbox_config.visible and not campaign_selection.visible
	if campaign_selection.visible:
		_animate_section_in(campaign_selection, -1)
		_pan_camera(-1)

func _pan_camera(direction: int) -> void:
	if menu_camera == null:
		return
	var target := _camera_home_position
	if direction != 0:
		var viewport_world_width := get_viewport_rect().size.x / menu_camera.zoom.x
		target.x += viewport_world_width * direction
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_property(menu_camera, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _animate_section_in(section: Control, from_direction: int) -> void:
	selected_button_marker.hide()
	var width := get_viewport_rect().size.x
	section.position.x = width * from_direction
	if _section_tween != null:
		_section_tween.kill()
	_section_tween = create_tween()
	_section_tween.tween_property(section, "position:x", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_section_out(section: Control, to_direction: int, completed: Callable) -> void:
	var width := get_viewport_rect().size.x
	if _section_tween != null:
		_section_tween.kill()
	_section_tween = create_tween()
	_section_tween.tween_property(section, "position:x", width * to_direction, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_section_tween.tween_callback(completed)

func _animate_menu_out(direction: int) -> void:
	var width := get_viewport_rect().size.x
	menu_content.visible = true
	menu_content.global_position = _menu_content_home_global_position
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.tween_property(menu_content, "global_position:x", _menu_content_home_global_position.x + width * direction, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_callback(func() -> void: menu_content.visible = false)

func _animate_menu_in(from_direction: int) -> void:
	var width := get_viewport_rect().size.x
	menu_content.global_position = _menu_content_home_global_position + Vector2(width * from_direction, 0)
	menu_content.visible = true
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.tween_property(menu_content, "global_position", _menu_content_home_global_position, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_callback(func() -> void: menu_content.global_position = _menu_content_home_global_position)

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
