extends Control

@onready var camera = %Camera
@onready var root = $MarginContainer

@onready var room_name_label = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var room_delete_button = $MarginContainer/MarginContainer/VBoxContainer/Button
@onready var room_describtion_label = $MarginContainer/MarginContainer/VBoxContainer/LabelDescribtion
@onready var room_upgrade_hbox = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/UpgradeSelection

var room : RoomBase = null

func _ready():
	HoverHandler.click_hovered_node_signal.connect(_on_clicked_room)
	room_delete_button.pressed.connect(_on_delete_room_clicked)
	root.hide()
	
func _on_clicked_room(clicked_room : RoomBase):
	
	room = clicked_room
	
	var valid_room = clicked_room != null and clicked_room is not RoomEmpty
	
	root.visible = valid_room
	
	if not valid_room:
		return
	
	room_name_label.text = clicked_room.get_script().get_global_name().trim_prefix("Room")
	room_delete_button.visible = room is not RoomJunk
	
	#var describtion = room.describtion
	#room_describtion_label.visible = describtion != ""
	#if describtion != "":
		#room_describtion_label.text = describtion
		
	
	room_upgrade_hbox.get_parent().visible = room.has_upgrades
	if room.has_upgrades:
			
		# keep index 0 as template, delete the rest
		Util.delete_all_children_execept_index_0(room_upgrade_hbox)

		var template = room_upgrade_hbox.get_child(0)
		template.visible = false

		# clone template for each upgrade
		for upgrade : RoomUpgrade in room.upgrades:
			var clone := template.duplicate()
			room_upgrade_hbox.add_child(clone)
			var content_root = clone.get_child(0).get_child(0)
			content_root.get_child(0).text = upgrade.name
			content_root.get_child(1).text = str("+", upgrade.price, " $")
			content_root.get_child(2).texture = upgrade.icon
			content_root.get_child(3).text = str("-", upgrade.cost, " $")
			clone.pressed.connect(room.try_set_upgrade.bind(upgrade))
			clone.show()
			
	root.size = Vector2(root.size.x, root.get_combined_minimum_size().y)
	
	var world_position = clicked_room.get_top_center_position()
	var ui_position = Util.world_to_ui_position(world_position, self, camera)
	root.global_position = ui_position - Vector2(root.size.x / 2, root.size.y) - Vector2(0,4)
	
func _on_delete_room_clicked():
	if room == null:
		return
		
	Global.UI.confirm.show_dialogue("You are about to delete this room. You will not get any money back but can place a different room here. Are you sure?", Global.Building.delete_room.bind(room))
	root.hide()
