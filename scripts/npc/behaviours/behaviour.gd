extends Node

class_name Behaviour
var npc
var isRunning = true

func _init():
	start_loop()
	
func start_loop():	
	while not npc:
		await endOfFrame()	
	loop()
	
func loop():
	print("loop base, make sure to override in inheriting scripts")
	
func pause(duration):
	print(str("pause for ", duration, "s"))
	return get_tree().create_timer(duration).timeout
	
func endOfFrame():
	return get_tree().process_frame
