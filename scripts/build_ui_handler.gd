extends Control

@onready var buttonDummy : Button = $GridContainer/Button;

func _ready():
	buttonDummy.visible = false
	create_button("Stairs", Global.Building.room_stairs, 100, RoomStairs.custom_placement_check)
	create_button("Table", Global.Building.room_table, 100)
	create_button("Bar", Global.Building.room_bar, 300)
	create_button("Buttery", Global.Building.room_buttery, 200)
	create_button("Brewery", Global.Building.room_brewery, 500)
	
func create_button(name, packedScene : PackedScene, cost : int, custom_placement_check = null):
	var instance : Button = buttonDummy.duplicate()
	buttonDummy.get_parent().add_child(instance)
	instance.visible = true
	instance.text = str(name, ", ", cost, "$")
	instance.pressed.connect(PlacementHandler.start_building.bind(packedScene, cost, custom_placement_check))
	
