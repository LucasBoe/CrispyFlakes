extends MenuUITab
class_name BuildMenuUITab

@onready var tab_cointainer : TabBar = $TabBar
@onready var buttonDummy : Button = $GridContainer/Button

var tier_icons = [
	preload("res://assets/sprites/ui/icon_locked_1.png"),
	preload("res://assets/sprites/ui/icon_locked_2.png"),
	preload("res://assets/sprites/ui/icon_locked_3.png"),
	preload("res://assets/sprites/ui/icon_locked_4.png"),
]

var all_buttons = []

var button_instances = {}

var buttery_button;
var brewery_button;

func _ready():
	tab_cointainer.tab_changed.connect(_on_tab_changed)
	
	create_button(0, 0, "Table", Global.Building.room_table, 30)
	create_button(0, 1, "Stairs", Global.Building.room_stairs, 30, RoomStairs.custom_placement_check)
	create_button(0,2,"Well", Global.Building.room_well, 25, RoomWell.custom_placement_check)
	create_button(1,0,"Bar", Global.Building.room_bar, 40)	
	brewery_button = create_button(1, 1, "Brewery", Global.Building.room_brewery, 30)
	buttery_button = create_button(1, 1, "Buttery", Global.Building.room_buttery, 30)
	create_button(2,0, "Outhouse", Global.Building.room_outhouse, 10, RoomOuthouse.custom_placement_check)
	create_button(2,2, "Bath", Global.Building.room_bath, 30)
	buttonDummy.hide()
	
	_on_tab_changed(0)
	
func create_button(index, tier, name, packedScene : PackedScene, cost : int, custom_placement_check = null):
	var instance : Button = buttonDummy.duplicate()
	buttonDummy.get_parent().add_child(instance)
	instance.visible = true
	instance.text = str(name, ", ", cost, "$")
	instance.icon = tier_icons[tier]
	instance.pressed.connect(PlacementHandler.start_building.bind(packedScene, cost, custom_placement_check))
	instance.pressed.connect(SoundPlayer.mouse_click_down.play)
	
	if not button_instances.has(index):
		button_instances[index] = {}
		
	if not button_instances[index].has(tier):
		button_instances[index][tier] = []
		
	button_instances[index][tier].append(instance)
		
	#all_buttons.append(instance)
	return instance

func _on_tab_changed(tab):
	
	SoundPlayer.mouse_click_down.play()
	
	#hide previous
	for x in button_instances.values():
		for y in x.values():
			for button in y:
				button.hide()
	
	if not button_instances.has(tab):
		return
	
	for tier in button_instances[tab]:
		for button in button_instances[tab][tier]:
			button.show()
			
			if TierHandler.current_tier >= tier:
				button.icon = null
				button.disabled = false
