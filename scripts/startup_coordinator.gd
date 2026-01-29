extends Node

var done = false

func _process(delta):
	if done:
		return
	
	for i in 1:
		Global.NPCSpawner.SpawnNewWorker(Vector2(-24,0))
		
	TutorialHandler.start_tutorial()
		
	done = true
