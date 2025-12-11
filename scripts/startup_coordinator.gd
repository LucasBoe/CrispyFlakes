extends Node

var done = false

func _process(delta):
	if done:
		return
		
	ResourceHandler.change_resource(Enum.Resources.MONEY, 500)
	
	for i in 2:
		Global.NPCSpawner.SpawnNewWorker()
		
	done = true
