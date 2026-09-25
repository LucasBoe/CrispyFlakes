extends Control
class_name MenuUIHandler

@onready var build_tab = $MarginContainer/UIBuild
@onready var settings_tab = $MarginContainer/UISettings
@onready var progression_tab = $MarginContainer/UIProgressionTree
@onready var scenario_tab = $MarginContainer/UIScenarioInfo
@onready var save_game_menu = $SaveGameMenu
@onready var leave_dialog: Control = $LeaveGameDialog
@onready var cancel_leave_button: Button = %CancelLeaveButton
@onready var leave_button: Button = %LeaveButton

@onready var build_button = $HBoxContainer/Button_Build
@onready var settings_button = $HBoxContainer/Button_Settings
@onready var progression_button = $HBoxContainer/Button_Progression
@onready var scenario_button = $HBoxContainer/Button_Scenario
@onready var _progression_glow_icon: TextureRect = $HBoxContainer/Button_Progression/GlowIcon

var visible_tab = null
var all_tabs : Array
var _tab_to_button: Dictionary = {}
var _tutorial_menu_gating_active := false
var _tutorial_available_tabs: Dictionary = {}
var _progression_glow_material: ShaderMaterial
var _progression_glow_tween: Tween
var _return_to_menu_after_save := false
var _returning_to_menu := false

func _ready():
	settings_tab.save_requested.connect(_open_save_menu.bind(false))
	settings_tab.save_and_menu_requested.connect(_open_save_menu.bind(true))
	settings_tab.menu_requested.connect(_show_leave_confirmation)
	cancel_leave_button.pressed.connect(_cancel_leave)
	leave_button.pressed.connect(_return_to_main_menu)
	save_game_menu.back_requested.connect(_on_save_menu_back)
	save_game_menu.save_completed.connect(_on_save_completed)
	bind_slot(build_button, build_tab)
	bind_slot(progression_button, progression_tab)
	bind_slot(settings_button, settings_tab)
	bind_slot(scenario_button, scenario_tab)
	set_tab(null)

	_progression_glow_material = _progression_glow_icon.material as ShaderMaterial
	progression_tab.visibility_changed.connect(_on_progression_tab_visibility_changed)
	_refresh_menu_gating()
	_refresh_progression_shader_time()
	_hide_progression_glow_overlay()
	_refresh_scenario_button_visibility()

func _open_save_menu(return_to_menu: bool) -> void:
	if leave_dialog.visible or _returning_to_menu:
		return
	_return_to_menu_after_save = return_to_menu
	save_game_menu.open_for_saving()
	if return_to_menu:
		save_game_menu.title.text = "SAVE & GO TO MENU"

func _on_save_menu_back() -> void:
	var button: Button = settings_tab.save_and_menu_button if _return_to_menu_after_save else settings_tab.save_button
	_return_to_menu_after_save = false
	button.grab_focus()

func _on_save_completed(_path: String) -> void:
	if _return_to_menu_after_save:
		_return_to_menu_after_save = false
		_return_to_main_menu.call_deferred()

func _show_leave_confirmation() -> void:
	if save_game_menu.visible or _returning_to_menu:
		return
	TimeHandler.push_pause_lock(self)
	leave_dialog.show()
	cancel_leave_button.grab_focus()

func _cancel_leave() -> void:
	if _returning_to_menu:
		return
	leave_dialog.hide()
	TimeHandler.pop_pause_lock(self)
	settings_tab.menu_button.grab_focus()

func _input(event: InputEvent) -> void:
	if leave_dialog.visible and event.is_action_pressed("ui_cancel"):
		_cancel_leave()
		get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if leave_dialog.visible:
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	TimeHandler.pop_pause_lock(self)

func _return_to_main_menu() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	leave_button.disabled = true
	cancel_leave_button.disabled = true
	await SaveHandler.end_session()
	var error := get_tree().change_scene_to_file("res://scenes/mainmenuscene.tscn")
	if error == OK:
		TimeHandler.set_time(TimeHandler.NORMAL_TIME)
	else:
		_returning_to_menu = false
		leave_button.disabled = false
		cancel_leave_button.disabled = false
		save_game_menu.status_label.text = "Could not open the main menu: %s." % error_string(error)

func _process(_delta: float) -> void:
	_refresh_progression_shader_time()
	_refresh_scenario_button_visibility()

func _on_ui_close():
	set_tab(null)

func bind_slot(button, tab):
	all_tabs.append(tab)
	_tab_to_button[tab] = button
	button.pressed.connect(set_tab.bind(tab))

func set_tab(tab):
	if save_game_menu.visible or leave_dialog.visible or _returning_to_menu:
		return
	if tab != null and not _is_tab_available(tab):
		return

	if visible:
		SoundPlayer.play_ui_click_down()
	else:
		SoundPlayer.play_ui_click_up()

	if tab != null and tab == visible_tab:
		tab.visible = not tab.visible
		visible_tab = tab if tab.visible else null
	else:
		for t in all_tabs:
			t.visible = t == tab and _is_tab_available(t)
		visible_tab = tab

	_refresh_progression_button_glow()

func start_tutorial_menu_gating() -> void:
	_tutorial_menu_gating_active = true
	_tutorial_available_tabs.clear()
	_tutorial_available_tabs[settings_tab] = true
	_refresh_menu_gating()

func unlock_tutorial_progression_menu() -> void:
	_set_tutorial_tab_available(progression_tab, true)

func unlock_tutorial_build_menu() -> void:
	_set_tutorial_tab_available(build_tab, true)

func finish_tutorial_menu_gating() -> void:
	_tutorial_menu_gating_active = false
	_tutorial_available_tabs.clear()
	_refresh_menu_gating()

func _set_tutorial_tab_available(tab: Control, available: bool) -> void:
	if available:
		_tutorial_available_tabs[tab] = true
	else:
		_tutorial_available_tabs.erase(tab)
	_refresh_menu_gating()

func _refresh_menu_gating() -> void:
	for tab in all_tabs:
		var available: bool = _is_tab_available(tab)
		var button: Button = _tab_to_button.get(tab) as Button
		if button != null:
			button.visible = available
			button.disabled = not available
		if not available:
			tab.hide()
			if visible_tab == tab:
				visible_tab = null

	_refresh_progression_button_glow()

func _refresh_scenario_button_visibility() -> void:
	if scenario_button == null:
		return
	var has_scenario: bool = ScenarioHandler.get_current_scenario() != null
	if scenario_button.visible == has_scenario:
		return
	scenario_button.visible = has_scenario and _is_tab_available(scenario_tab)
	if not has_scenario and visible_tab == scenario_tab:
		set_tab(null)

func _is_tab_available(tab) -> bool:
	if tab == null:
		return true
	if not _tutorial_menu_gating_active:
		return true
	return bool(_tutorial_available_tabs.get(tab, false))

func _on_progression_tab_visibility_changed() -> void:
	if progression_tab.visible:
		visible_tab = progression_tab
		TimeHandler.push_pause_lock(progression_tab)
	else:
		if visible_tab == progression_tab:
			visible_tab = null
		TimeHandler.pop_pause_lock(progression_tab)
	_refresh_progression_button_glow()

func _refresh_progression_button_glow() -> void:
	if _progression_glow_icon == null or _progression_glow_material == null:
		return

	_progression_glow_material.set_shader_parameter("is_unlocked", false)
	_progression_glow_material.set_shader_parameter("is_active", false)
	_stop_progression_glow_pulse()
	_hide_progression_glow_overlay()

func _start_progression_glow_pulse() -> void:
	if _progression_glow_tween != null:
		return
	_show_progression_glow_overlay()
	var tween := create_tween().set_ignore_time_scale(true)
	tween.set_loops()
	tween.tween_interval(0.65)
	tween.tween_callback(Callable(self, "_hide_progression_glow_overlay"))
	tween.tween_interval(1.1)
	tween.tween_callback(Callable(self, "_show_progression_glow_overlay"))
	_progression_glow_tween = tween

func _refresh_progression_shader_time() -> void:
	if _progression_glow_material == null:
		return
	_progression_glow_material.set_shader_parameter("ui_time", float(Time.get_ticks_msec()) / 1000.0)

func _stop_progression_glow_pulse() -> void:
	if _progression_glow_tween == null:
		return
	_progression_glow_tween.kill()
	_progression_glow_tween = null

func _show_progression_glow_overlay() -> void:
	_progression_glow_icon.show()

func _hide_progression_glow_overlay() -> void:
	_progression_glow_icon.hide()
