extends Node2D

var resources : Dictionary = {}
signal on_resource_changed
signal on_animate_resource_add

func _ready():
	for r in Enum.Resources.values():
		resources[r] = 0
		print("init resource", r)
	
func change_resource(resource, change):
	var r = resource as Enum.Resources
	print("on change resource", r , change)
	resources[r] += change
	on_resource_changed.emit(r, resources[r], change)
	
func add_animated(resource, amount, global_pos):
	var animation_duration = 1.0
	on_animate_resource_add.emit(resource, amount, global_pos, animation_duration)
	await get_tree().create_timer(animation_duration).timeout
	change_resource(resource, amount)
	

func _process(delta):
	if Input.is_key_pressed(KEY_4):
		add_animated(Enum.Resources.MONEY, 4, get_global_mouse_position())
