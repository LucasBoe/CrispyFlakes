extends Control

@onready var buttonDummy : Button = $GridContainer/Button;

func _ready():
	buttonDummy.visible = false
	create_button("Bar", Global.Building.room_bar, 300)
	
func create_button(name, packedScene : PackedScene, cost : int):
	var instance : Button = buttonDummy.duplicate()
	buttonDummy.get_parent().add_child(instance)
	instance.visible = true
	instance.text = str(name, ", ", cost, "$")
	instance.pressed.connect(PlacementHandler.start_building.bind(packedScene, cost))
	
