extends MenuUITab
class_name BuildMenuUITab

@onready var tab_cointainer : TabBar = $MarginContainer/GridContainer/TabBar
@onready var room_tier_dummy : Control = $MarginContainer/GridContainer/RoomTierDummy

@onready var hover_info_room_box_root = $UIRoomHoverInfo
@onready var hover_info_room_name_label : Label = %RoomBuildHoverInfoNameLabel
@onready var hover_info_room_desc_label : RichTextLabel = %RoomBuildHoverInfoDescLabel
@onready var hover_info_room_preview_texture_rect : TextureRect = %RoomBuildHoverInfoRoomPreviewTextureRect

var groups = {}

var all_tiers = []
var button_dummies = []

var buttery_button;
var brewery_button;

func _ready():
	tab_cointainer.tab_changed.connect(_on_tab_changed)
	
	var group = room_group.new(groups)
	
	create_button(group, Global.Building.room_data_table)
	create_button(group, Global.Building.room_data_stairs, RoomStairs.custom_placement_check)
	create_button(group, Global.Building.room_data_well)
	create_button(group, Global.Building.room_data_bar)
	brewery_button = create_button(group, Global.Building.room_data_brewery)
	buttery_button = create_button(group, Global.Building.room_data_buttery)
	create_button(group, Global.Building.room_data_outhouse, RoomOuthouse.custom_placement_check)
	create_button(group, Global.Building.room_data_bath)
	_on_tab_changed(0)
	room_tier_dummy.hide()
	
func create_button(group : room_group, data : RoomData, custom_placement_check = null):	
	
	var tier = data.tier
	while group.tiers.size() <= tier:
		group.create_new_tier_dummy(room_tier_dummy)
		
	var buttonDummy = group.button_dummies[tier]
		
	var instance : Button = buttonDummy.duplicate()
	buttonDummy.get_parent().add_child(instance)
	instance.visible = true
	instance.icon = data.room_icon
	instance.pressed.connect(PlacementHandler.start_building.bind(data, custom_placement_check))
	instance.pressed.connect(SoundPlayer.mouse_click_down.play)
	instance.mouse_entered.connect(_on_hover_enter.bind(instance, data))
	instance.mouse_exited.connect(_on_hover_exit.bind(instance, data))
	instance.show()
	
	if not group.button_instances.has(tier):
		group.button_instances[tier] = []
		
	group.button_instances[tier].append(instance)
	
	return instance
	
func _on_hover_enter(button : Button, data : RoomData):
	hover_info_room_name_label.text = data.room_name
	hover_info_room_desc_label.text = data.room_desc
	hover_info_room_preview_texture_rect.texture = data.room_preview
	return

func _on_hover_exit(button : Button, data : RoomData):
	return

func _on_tab_changed(tab):
	
	SoundPlayer.mouse_click_down.play()
	
	var group = groups[tab]
	
	#hide previous
	for g in groups.values():
		for x in g.button_instances.values():
				for button in x:
					button.hide()
		
	for tier in group.button_instances.keys():
		for button in group.button_instances[tier]:
			button.show()
			
		group.overlays[tier].visible = tier > TierHandler.current_tier
			

class room_group:
	var group_name : String
	var tiers = []
	var overlays = []
	var button_dummies = []
	var button_instances = {}
	
	func _init(groups):
		groups[groups.size()] = self

	func create_new_tier_dummy(tier_dummy : Control):
		
		var tier_level = tiers.size()
		var clone = tier_dummy.duplicate()
		tier_dummy.get_parent().add_child(clone)
		
		tiers.append(clone)
		var overlay = clone.get_child(1)
		overlays.append(overlay)
		var overlay_number_label = overlay.get_child(1).get_child(0).get_child(1) 
		overlay_number_label.text = str(TierHandler.tier_visitors_needed[tier_level], " Guests")
		var button_dummy = clone.get_child(0).get_child(0).get_child(0)
		button_dummies.append(button_dummy)
		button_dummy.hide()
		return self
