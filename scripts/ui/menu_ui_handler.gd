extends Control
class_name MenuUIHandler

@onready var worker_tab = $MarginContainer/UIWorkers
@onready var build_tab = $MarginContainer/UIBuild
@onready var settings_tab = $MarginContainer/UISettings
@onready var progression_tab = $MarginContainer/UIProgressionTree

@onready var worker_button = $HBoxContainer/Button_Workers
@onready var build_button = $HBoxContainer/Button_Build
@onready var settings_button = $HBoxContainer/Button_Settings
@onready var progression_button = $HBoxContainer/Button_Progression
@onready var _progression_glow_icon: TextureRect = $HBoxContainer/Button_Progression/GlowIcon

var visible_tab = null
var all_tabs : Array
var _progression_glow_material: ShaderMaterial
var _progression_glow_tween: Tween

func _ready():
	bind_slot(worker_button, worker_tab)
	bind_slot(build_button, build_tab)
	bind_slot(progression_button, progression_tab)
	bind_slot(settings_button, settings_tab)
	set_tab(null)

	_progression_glow_material = _progression_glow_icon.material as ShaderMaterial
	ProgressionHandler.points_changed.connect(_on_progression_points_changed)
	progression_button.mouse_entered.connect(_refresh_progression_button_glow)
	progression_button.mouse_exited.connect(_refresh_progression_button_glow)
	progression_tab.visibility_changed.connect(_on_progression_tab_visibility_changed)
	_on_progression_points_changed(ProgressionHandler.get_points())

func _on_ui_close():
	set_tab(null)

func bind_slot(button, tab):
	all_tabs.append(tab)
	button.pressed.connect(set_tab.bind(tab))

func set_tab(tab):
	if visible:
		SoundPlayer.play_ui_click_down()
	else:
		SoundPlayer.play_ui_click_up()

	if tab != null and tab == visible_tab:
		tab.visible = not tab.visible
		visible_tab = tab if tab.visible else null
	else:
		for t in all_tabs:
			t.visible = t == tab
		visible_tab = tab

	_refresh_progression_button_glow()

func _on_progression_tab_visibility_changed() -> void:
	if progression_tab.visible:
		visible_tab = progression_tab
	elif visible_tab == progression_tab:
		visible_tab = null
	_refresh_progression_button_glow()

func _on_progression_points_changed(_points: int) -> void:
	_refresh_progression_button_glow()

func _refresh_progression_button_glow() -> void:
	if _progression_glow_icon == null or _progression_glow_material == null:
		return

	var should_notify: bool = ProgressionHandler.get_points() > 0 and not progression_tab.visible
	var is_hovered: bool = progression_button.is_hovered()
	_progression_glow_material.set_shader_parameter("is_unlocked", should_notify)
	_progression_glow_material.set_shader_parameter("is_active", should_notify and is_hovered)

	if not should_notify:
		_stop_progression_glow_pulse()
		_hide_progression_glow_overlay()
	elif is_hovered:
		_stop_progression_glow_pulse()
		_show_progression_glow_overlay()
	else:
		_start_progression_glow_pulse()

func _start_progression_glow_pulse() -> void:
	if _progression_glow_tween != null:
		return
	_show_progression_glow_overlay()
	var tween := create_tween()
	tween.set_loops()
	tween.tween_interval(0.65)
	tween.tween_callback(Callable(self, "_hide_progression_glow_overlay"))
	tween.tween_interval(1.1)
	tween.tween_callback(Callable(self, "_show_progression_glow_overlay"))
	_progression_glow_tween = tween

func _stop_progression_glow_pulse() -> void:
	if _progression_glow_tween == null:
		return
	_progression_glow_tween.kill()
	_progression_glow_tween = null

func _show_progression_glow_overlay() -> void:
	_progression_glow_icon.show()

func _hide_progression_glow_overlay() -> void:
	_progression_glow_icon.hide()
