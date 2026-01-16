extends MenuUITab

@onready var buttonDummy : Button = $GridContainer/Button

var all_buttons = []

func _ready():
	create_button("Stairs", Global.Building.room_stairs, 100, RoomStairs.custom_placement_check)
	create_button("Table", Global.Building.room_table, 100)
	create_button("Well", Global.Building.room_well, 150, RoomWell.custom_placement_check)
	create_button("Bar (Water)", Global.Building.room_bar_water, 100)	
	create_button("Bar (Beer)", Global.Building.room_bar_beer, 300)
	create_button("Bar (Wiskey)", Global.Building.room_bar_wiskey, 500)
	create_button("Buttery", Global.Building.room_buttery, 200)
	create_button("Bath", Global.Building.room_bath, 250)
	create_button("Brewery", Global.Building.room_brewery, 500)
	buttonDummy.hide()
	
func create_button(name, packedScene : PackedScene, cost : int, custom_placement_check = null):
	var instance : Button = buttonDummy.duplicate()
	buttonDummy.get_parent().add_child(instance)
	instance.visible = true
	instance.text = str(name, ", ", cost, "$")
	instance.pressed.connect(PlacementHandler.start_building.bind(packedScene, cost, custom_placement_check))
	instance.pressed.connect(SoundPlayer.mouse_click_down.play)
	all_buttons.append(instance)
