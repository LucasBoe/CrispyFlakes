extends MenuUITab
class_name BuildMenuUITab

@onready var buttonDummy : Button = $GridContainer/Button

var all_buttons = []

var buttery_button;
var brewery_button;

func _ready():
	create_button("Stairs", Global.Building.room_stairs, 30, RoomStairs.custom_placement_check)
	buttery_button = create_button("Buttery", Global.Building.room_buttery, 30)
	create_button("Table", Global.Building.room_table, 30)
	create_button("Bar", Global.Building.room_bar, 40)	
	brewery_button = create_button("Brewery", Global.Building.room_brewery, 30)
	create_button("Bath", Global.Building.room_bath, 30)
	#create_button("Well", Global.Building.room_well, 25, RoomWell.custom_placement_check)
	buttonDummy.hide()
	
func create_button(name, packedScene : PackedScene, cost : int, custom_placement_check = null):
	var instance : Button = buttonDummy.duplicate()
	buttonDummy.get_parent().add_child(instance)
	instance.visible = true
	instance.text = str(name, ", ", cost, "$")
	instance.pressed.connect(PlacementHandler.start_building.bind(packedScene, cost, custom_placement_check))
	instance.pressed.connect(SoundPlayer.mouse_click_down.play)
	all_buttons.append(instance)
	return instance
