extends Node2D

@onready var speechbubbe_dummy = $SpeechbubbleDummy
@onready var need_bar_dummy = $NeedBarDummy
@onready var npc_notification_dummy = $NPCNotificationDummy

#notification textures
const ICON_PLUS_1 = preload("uid://be0je5p0o105l")
const ICON_PLUS_2 = preload("uid://dy3mtejlsjju8")
const ICON_PLUS_3 = preload("uid://ldes6kwybucd")
const ICON_MINUS_1 = preload("uid://b0jx3u4nuuyji")
const ICON_MINUS_2 = preload("uid://com64xsv8rgjb")
const ICON_MINUS_3 = preload("uid://bbdxndq8d6dak")
const ICON_FIGHT = preload("uid://cq7ltdnrruphx")
const ICON_HANDCUFFS = preload("uid://cl2jtn5jtk0yh")

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

func _create_from_dummy(dummy, duration) -> instance_info:
	var instance = dummy.duplicate()
	dummy.get_parent().add_child(instance)
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

func _process(delta):
	speechbubbe_dummy.global_position = get_global_mouse_position() - speechbubbe_dummy.pivot_offset

	for i in instances:
		if i.target_object != null:
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
