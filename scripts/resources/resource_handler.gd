extends Node2D

var resources : Dictionary = {}
signal on_resource_changed
signal on_animate_resource_add
signal on_animate_resource_spend
signal on_money_changed

var money_transaction_history = {}

func _ready():
	for r in Enum.Resources.values():
		resources[r] = 0 if r != Enum.Resources.MONEY else 100
		print("init resource", r)
	
func change_resource(resource, change):
	var r = resource as Enum.Resources
	#print("on change resource ", Enum.Resources.keys()[r], " (", change, ")")
	resources[r] += change
	on_resource_changed.emit(r, resources[r], change)
	if r == Enum.Resources.MONEY and change < 0:
		MoneyHandler.spend(-change)
	
	#if r == Enum.Resources.MONEY:
		#for c in clamp(change, 1, 5):
			#SoundPlayer.play_coin()
			#await get_tree().create_timer(.05).timeout
			
	if not resource == Enum.Resources.MONEY:
		return
		
	var now : float = Global.time_now
	var day_duration : float = Global.DAY_DURATION

	money_transaction_history[now] = change

	for t in money_transaction_history.keys():
		#print(now, " - ", t, " > ", day_duration, (now - t) > day_duration)
		if (now - t) > day_duration:
			money_transaction_history.erase(t)
	
	on_money_changed.emit()

func change_money(change):
	change_resource(Enum.Resources.MONEY, change)

func has(resource, amount):
	if not resources.has(resource):
		return false
		
	if resources[resource] < amount:
		return false
		
	return true
			
func has_money(amount) -> bool:
	return has(Enum.Resources.MONEY, amount)

func add_animated(resource, amount, global_pos, room_location: Vector2i = Vector2i(-9999, -9999)):

	if resource == Enum.Resources.MONEY:
		SoundPlayer.play_treasure()

	var animation_duration = 1.0
	on_animate_resource_add.emit(resource, amount, global_pos, animation_duration)
	await get_tree().create_timer(animation_duration).timeout
	change_resource(resource, amount)
	if resource == Enum.Resources.MONEY and amount > 0:
		if room_location != Vector2i(-9999, -9999):
			MoneyHandler.deposit(room_location, amount)
		else:
			MoneyHandler.deposit_free(amount)
	

func spend_animated(amount: int, global_pos: Vector2) -> void:
	change_money(-amount)
	SoundPlayer.play_treasure()
	var animation_duration = .3
	on_animate_resource_spend.emit(amount, global_pos, animation_duration)
	await get_tree().create_timer(animation_duration).timeout

func _process(delta):
	if Input.is_key_pressed(KEY_5):
		add_animated(Enum.Resources.MONEY, 4, get_global_mouse_position())
