extends Node2D

@onready var speechbubbe_dummy = $SpeechbubbleDummy
@onready var need_bar_dummy = $NeedBarDummy #new type

var instances = []

class instance_info:
	var instance
	var target_object
	var target_position
	var offset
	var lifetime_left

func _ready():
	speechbubbe_dummy.hide()
	need_bar_dummy.hide()
	
func _create_from_dummy(dummy) -> instance_info:
	var instance = dummy.duplicate()
	dummy.get_parent().add_child(instance)

	instance.visible = true

	var i := instance_info.new()
	i.instance = instance
	i.lifetime_left = 3.0
	instances.append(i)
	return i

	
func create(text, icon, color):
	var i := _create_from_dummy(speechbubbe_dummy)
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

func create_notification_static(text, target_position, icon = null, color = Color.BLACK):
	var i = create(text, icon, color)
	i.instance.position = target_position - i.instance.pivot_offset
	return i

func create_notification_dynamic(text, target : Node2D = null, offset = Vector2.ZERO, icon = null, color = Color.BLACK):
	var i = create(text, icon, color)
	i.target_object = target
	i.offset = offset
	return i
	
func create_notification_need(need: Enum.Need, value: float, target: Node2D = null, offset := Vector2(-8,-46)):
	var i := _create_from_dummy(need_bar_dummy)
	var instance = i.instance

	i.target_object = target
	i.offset = offset

	var icon := Enum.need_to_icon(need)

	var tex: TextureRect = instance.get_node("IconTextureRect")
	tex.texture = icon

	var bar: ProgressBar = instance.get_node("ProgressBar")
	bar.value = clamp(value, bar.min_value, bar.max_value)

	return i
	
func _process(delta):
	speechbubbe_dummy.global_position = get_global_mouse_position() - speechbubbe_dummy.pivot_offset
	
	for i in instances:
		if i.target_object != null:
			var p = i.target_object.global_position + i.offset
			i.instance.global_position = p
			
		i.lifetime_left -= delta
		if i.lifetime_left <= 0.0:
			try_kill(i)

func try_kill(i):
	
	if not i:
		return
		
	if not i.instance:
		return
	
	i.instance.queue_free()
	instances.erase(i)
