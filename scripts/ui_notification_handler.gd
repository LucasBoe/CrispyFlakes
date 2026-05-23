extends Node2D

@onready var speechbubbe_dummy = $SpeechbubbleDummy
@onready var need_bar_dummy = $NeedBarDummy
@onready var npc_notification_dummy = $NPCNotificationDummy
@onready var fight_bar_dummy = $FightBarDummy
@onready var _world_layer: CanvasLayer = $WorldNotificationLayer
@onready var _ui_layer: CanvasLayer = $UINotificationLayer

#notification textures
const ICON_PLUS_1 = preload("uid://be0je5p0o105l")
const ICON_PLUS_2 = preload("uid://dy3mtejlsjju8")
const ICON_PLUS_3 = preload("uid://ldes6kwybucd")
const ICON_MINUS_1 = preload("uid://b0jx3u4nuuyji")
const ICON_MINUS_2 = preload("uid://com64xsv8rgjb")
const ICON_MINUS_3 = preload("uid://bbdxndq8d6dak")
const ICON_FIGHT = preload("uid://cq7ltdnrruphx")
const ICON_HANDCUFFS = preload("uid://cl2jtn5jtk0yh")
const ICON_HANDCUFFED = preload("uid://d2mm1tn7w7oot")
const ICON_KNOCKED_OUT = preload("res://assets/sprites/ui/icon_knocked_out.png")
const ICON_INJURED = preload("uid://cfjnntc5pridd")
const ICON_TREATED = preload("uid://cmglyexhx4ow7")
const ICON_FUGITIVE = preload("uid://dcde01v5i4hgb")
const ICON_ROBBER = preload("uid://ccudedp2r2ik6")
const ICON_EWW = preload("res://assets/sprites/icon_eww.png")

var instances = []
const DEFAULT_LIFETIME = 3.0

class instance_info:
	var instance
	var target_object
	var target_position
	var offset
	var lifetime_left
	var is_permanent = false

func _ready():
	speechbubbe_dummy.hide()
	need_bar_dummy.hide()
	npc_notification_dummy.hide()
	fight_bar_dummy.hide()

func _create_from_dummy(dummy, duration) -> instance_info:
	var instance = dummy.duplicate()
	_world_layer.add_child(instance)
	instance.visible = true

	var i := instance_info.new()
	i.instance = instance
	i.lifetime_left = duration
	instances.append(i)
	return i

func create(text, icon, color, duration):
	var i := _create_from_dummy(speechbubbe_dummy, duration)
	var instance: PanelContainer = i.instance

	var tex : TextureRect = instance.get_node("MarginContainer/HBoxContainer/MarginContainer/TextureRect")
	if icon:
		tex.texture = icon
		tex.visible = true
	else:
		tex.visible = false

	instance.get_node("MarginContainer/HBoxContainer/Label").text = text.to_upper()

	var theme : Theme = load("res://assets/notification.tres").duplicate()
	var theme_tex = theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxTexture
	theme_tex.modulate_color = color
	theme.set_stylebox("panel", "PanelContainer", theme_tex)
	instance.theme = theme

	return i

func create_notification_static(text, target_position, icon = null, color = Color.BLACK, duration = DEFAULT_LIFETIME):
	var i = create(text, icon, color, duration)
	i.instance.position = target_position - i.instance.pivot_offset
	return i

func create_notification_ui(text, screen_position: Vector2, icon = null, color = Color.BLACK, duration = DEFAULT_LIFETIME):
	var i = create(text, icon, color, duration)
	i.instance.reparent(_ui_layer, false)
	i.instance.position = screen_position - i.instance.pivot_offset
	return i

func create_notification_dynamic(text, target : Node2D = null, offset = Vector2.ZERO, icon = null, color = Color.BLACK, duration = DEFAULT_LIFETIME):
	var i = create(text, icon, color, duration)
	i.target_object = target
	i.offset = offset
	return i

func create_notification_need(need: Enum.Need, value: float, target: Node2D = null, offset := Vector2(-8,-46)):
	var i := _create_from_dummy(need_bar_dummy, DEFAULT_LIFETIME)
	var instance = i.instance

	i.target_object = target
	i.offset = offset

	var icon := Enum.need_to_icon(need)

	var tex: TextureRect = instance.get_node("IconTextureRect")
	tex.texture = icon

	var bar: ProgressBar = instance.get_node("ProgressBar")
	bar.value = clamp(value, bar.min_value, bar.max_value)

	return i

# New function for NPC notifications
func create_npc_notification(target: Node2D, texture: Texture2D, permanent: bool = false, offset := Vector2(0, -24), duration := DEFAULT_LIFETIME) -> instance_info:
	var i := _create_from_dummy(npc_notification_dummy, duration if not permanent else INF)
	var instance = i.instance

	i.target_object = target
	i.offset = offset - Vector2(texture.get_width() / 2, texture.get_height())
	i.is_permanent = permanent

	var tex: TextureRect = instance.get_node("TextureRect")
	tex.texture = texture

	return i

func create_npc_action_button(target: Node2D, texture: Texture2D, pressed_callback: Callable, permanent: bool = false, offset := Vector2(0, -24), duration := DEFAULT_LIFETIME) -> instance_info:
	var button := TextureButton.new()
	button.texture_normal = texture
	button.texture_hover = texture
	button.texture_pressed = texture
	button.ignore_texture_size = false
	button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	button.size = texture.get_size()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.z_index = 4100
	if pressed_callback.is_valid():
		button.pressed.connect(pressed_callback)
	_world_layer.add_child(button)

	var i := instance_info.new()
	i.instance = button
	i.target_object = target
	i.offset = offset - Vector2(texture.get_width() / 2, texture.get_height())
	i.is_permanent = permanent
	i.lifetime_left = duration if not permanent else INF
	instances.append(i)
	return i
	
func create_npc_health_bar(npc: NPC, color: Color) -> instance_info:
	var i := _create_from_dummy(fight_bar_dummy, INF)
	i.is_permanent = true
	i.target_object = npc
	i.offset = Vector2(-12, -24)
	var bar := i.instance.get_node("ProgressBar") as ProgressBar
	var fill_style := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill_style.bg_color = color
	bar.add_theme_stylebox_override("fill", fill_style)
	return i

func create_world_progress_bar(target: Node2D, offset: Vector2, color: Color, size := Vector2(28.0, 3.0)) -> instance_info:
	var bar := Control.new()
	bar.z_index = 3960
	bar.custom_minimum_size = Vector2.ZERO
	bar.size = size

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.0, 0.0, 0.0, 0.75)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = size
	bar.add_child(background)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size = size
	bar.add_child(fill)

	_world_layer.add_child(bar)

	var i := instance_info.new()
	i.instance = bar
	i.target_object = target
	i.offset = offset
	i.is_permanent = true
	i.lifetime_left = INF
	instances.append(i)
	return i

func update_npc_health_bar(i : instance_info, health_value : float):
	if not i or not i.instance:
		return
	var bar := i.instance.get_node("ProgressBar") as ProgressBar
	bar.value = health_value

func update_progress_bar(i: instance_info, value: float) -> void:
	if not i or not i.instance:
		return
	var bar := i.instance as Control
	if bar == null:
		return
	var fill := bar.get_node_or_null("Fill") as ColorRect
	if fill == null:
		return
	var clamped_value := clampf(value, 0.0, 1.0)
	fill.size = Vector2(bar.size.x * clamped_value, bar.size.y)

func _process(delta):
	speechbubbe_dummy.global_position = get_global_mouse_position() - speechbubbe_dummy.pivot_offset

	for i in instances.duplicate():
		if i.target_object != null:
			if not is_instance_valid(i.target_object):
				try_kill(i)
				continue
			var p = i.target_object.global_position + i.offset
			i.instance.global_position = p

		if not i.is_permanent:
			i.lifetime_left -= delta
			if i.lifetime_left <= 0.0:
				try_kill(i)

func try_kill(i : instance_info):
	if not i:
		return
	if not i.instance:
		return

	i.instance.queue_free()
	instances.erase(i)
