extends Node

class_name Behaviour
var npc : NPC
var isRunning = true

func _init():
	start_loop()
	
func start_loop():	
	while not npc:
		await endOfFrame()	
	loop()
	
func loop():
	print("loop base, make sure to override in inheriting scripts")
	
func move(target):
	npc.Navigation.set_target(target)
	while npc.Navigation.is_moving:	
		await endOfFrame()
	
func pause(duration):
	return get_tree().create_timer(duration).timeout
	
func endOfFrame():
	return get_tree().process_frame
