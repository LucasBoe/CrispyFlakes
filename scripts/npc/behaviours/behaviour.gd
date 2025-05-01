extends Node

class_name Behaviour
var npc

func _init():
	start_loop()
	
func start_loop():	
	while not npc:
		await get_tree().process_frame		
	loop()
	
func loop():
	print("loop base")
