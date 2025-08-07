extends Node2D

@onready var dummy = $Dummy;
var instances = []

class instance_info:
	var instance
	var target_object
	var target_position
	var offset
	var lifetime_left

func _ready():
	dummy.visible = false
	
func create(text, icon, color):
	var instance : PanelContainer = dummy.duplicate()
	dummy.get_parent().add_child(instance)
	
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

	
	instance.visible = true
	var i = instance_info.new()
	i.instance = instance
	i.lifetime_left = 3
	instances.append(i)
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
	
func _process(delta):
	dummy.global_position = get_global_mouse_position() - dummy.pivot_offset
	
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
