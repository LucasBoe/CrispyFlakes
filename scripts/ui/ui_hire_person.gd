extends Button

var hire_ui
var cost = 12

func _ready():
	self.pressed.connect(hire)
	
func hire():
	if ResourceHandler.has_money(cost):
		ResourceHandler.change_resource(Enum.Resources.MONEY, -cost)
		Global.NPCSpawner.SpawnNewWorker()
		queue_free()
		hire_ui.hide()
