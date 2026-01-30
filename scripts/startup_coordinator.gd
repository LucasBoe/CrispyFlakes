extends Node

var done = false

func _process(delta):
	if done:
		return
		
	TutorialHandler.start_tutorial()
		
	done = true
