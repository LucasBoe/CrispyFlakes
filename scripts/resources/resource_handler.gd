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
	print("on change resource ", Enum.Resources.keys()[r], " (", change, ")")
	resources[r] += change
	on_resource_changed.emit(r, resources[r], change)
	
	#if r == Enum.Resources.MONEY:
		#for c in clamp(change, 1, 5):
			#SoundPlayer.coin.play_random_pitch()
			#await get_tree().create_timer(.05).timeout

func has(resource, amount):
	if not resources.has(resource):
		return false
		
	if resources[resource] < amount:
		return false
		
	return true
			
func has_money(amount) -> bool:
	return has(Enum.Resources.MONEY, amount)

func add_animated(resource, amount, global_pos):
	
	if resource == Enum.Resources.MONEY:
		SoundPlayer.treasure.play_random_pitch()
	
	var animation_duration = 1.0
	on_animate_resource_add.emit(resource, amount, global_pos, animation_duration)
	await get_tree().create_timer(animation_duration).timeout
	change_resource(resource, amount)
	

func _process(delta):
	if Input.is_key_pressed(KEY_4):
		add_animated(Enum.Resources.MONEY, 4, get_global_mouse_position())
