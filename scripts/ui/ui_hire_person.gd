extends Button

var hire_ui

func _ready():
	self.pressed.connect(hire)
	
func hire():
	Global.NPCSpawner.SpawnNewWorker()
	queue_free()
	hire_ui.hide()
