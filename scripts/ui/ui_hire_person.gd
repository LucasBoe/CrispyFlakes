extends Button

var hire_ui

func _ready():
	self.pressed.connect(try_hire)
	
func try_hire():
	Global.UI.confirm.show_dialogue("You are about to hire somebody. You will have to pay them daily. Are you sure?", hire)
	
func hire():
	Global.NPCSpawner.SpawnNewWorker()
	queue_free()
	hire_ui.hide()
