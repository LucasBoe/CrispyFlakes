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
	
func progress(duration, bar : TextureProgressBar):
	var t = float(duration)
	bar.visible = true
	while t > 0:
		t -= get_process_delta_time()
		bar.value = (1.0 - (t / duration)) * 100
		await endOfFrame()
		
	bar.visible = false
	
func endOfFrame():
	return get_tree().process_frame
