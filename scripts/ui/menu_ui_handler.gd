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
@onready var notification_dot = $HBoxContainer/Button_Build/Notification_Dot

var visible_tab = null
var all_tabs : Array
var blink_tween : Tween
var _progression_glow_material: ShaderMaterial

const DOT_DEFAULT = preload("res://assets/sprites/ui/notification_dot_default.png")
const DOT_HOVERED = preload("res://assets/sprites/ui/notification_dot_hovered.png")

func _ready():
	bind_slot(worker_button, worker_tab)
	bind_slot(build_button, build_tab)
	bind_slot(progression_button, progression_tab)
	bind_slot(settings_button, settings_tab)
	set_tab(null)

	notification_dot.visible = false
	TierHandler.tier_unlocked_signal.connect(_on_tier_unlocked)
	build_button.mouse_entered.connect(_on_build_button_hover_enter)
	build_button.mouse_exited.connect(_on_build_button_hover_exit)

	_progression_glow_material = _progression_glow_icon.material as ShaderMaterial
	ProgressionHandler.points_changed.connect(_on_progression_points_changed)
	progression_button.mouse_entered.connect(_refresh_progression_button_glow)
	progression_button.mouse_exited.connect(_refresh_progression_button_glow)
	_on_progression_points_changed(ProgressionHandler.get_points())

func _on_tier_unlocked(_tier):
	notification_dot.visible = true
	notification_dot.texture = DOT_DEFAULT
	if blink_tween:
		blink_tween.kill()
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(notification_dot, "modulate:a", 0.0, 0.4)
	blink_tween.tween_property(notification_dot, "modulate:a", 1.0, 0.4)

func _on_build_button_hover_enter():
	if notification_dot.visible:
		notification_dot.texture = DOT_HOVERED

func _on_build_button_hover_exit():
	if notification_dot.visible:
		notification_dot.texture = DOT_DEFAULT

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
	else:
		for t in all_tabs:
			t.visible = t == tab

	visible_tab = tab

	if build_tab.visible:
		_hide_notification_dot()

func _hide_notification_dot():
	if blink_tween:
		blink_tween.kill()
		blink_tween = null
	notification_dot.modulate.a = 1.0
	notification_dot.visible = false
	notification_dot.texture = DOT_DEFAULT

func _on_progression_points_changed(_points: int) -> void:
	_refresh_progression_button_glow()

func _refresh_progression_button_glow() -> void:
	if _progression_glow_icon == null or _progression_glow_material == null:
		return

	var has_points := ProgressionHandler.get_points() > 0
	_progression_glow_icon.visible = has_points
	_progression_glow_material.set_shader_parameter("is_unlocked", has_points)
	_progression_glow_material.set_shader_parameter("is_active", has_points and progression_button.is_hovered())
