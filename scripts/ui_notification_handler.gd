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

func create_notification_dynamic(text, target : Node2D, offset = Vector2i.ZERO, icon = null, color = Color.BLACK):
	var i = create(text, icon, color)
	i.offset = offset
	
func _process(delta):
	dummy.position = get_global_mouse_position() - dummy.pivot_offset
	
	for i in instances:
		if i.target_object:
			i.instance.position = i.target_object + i.offset
			
		i.lifetime_left -= delta
		if i.lifetime_left <= 0.0:
			i.instance.queue_free()
			instances.erase(i)
