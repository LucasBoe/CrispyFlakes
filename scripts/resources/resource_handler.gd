extends Node

var resources : Dictionary = {}
signal on_resource_changed

func _ready():
	for r in Enum.Resources.values():
		resources[r] = 0
		print("init resource", r)
	
		
func change_resource(resource, change):
	var r = resource as Enum.Resources
	print("on change resource", r , change)
	resources[r] += change
	on_resource_changed.emit(r, resources[r], change)

func _process(delta):
	if Input.is_key_pressed(KEY_4):
		change_resource(Enum.Resources.MONEY, 4)
