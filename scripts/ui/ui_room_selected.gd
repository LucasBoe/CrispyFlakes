extends Control

@onready var camera = %Camera
@onready var root = $MarginContainer

@onready var room_name_label = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var room_delete_button = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/Button
@onready var room_upgrade_hbox = $MarginContainer/MarginContainer/VBoxContainer/UpgradeSelection

var room : RoomBase = null

func _ready():
	HoverHandler.click_room_signal.connect(_on_clicked_room)
	room_delete_button.pressed.connect(_on_delete_room_clicked)
	root.hide()
	
func _on_clicked_room(clicked_room : RoomBase):
	
	room = clicked_room
	
	var valid_room = clicked_room != null and clicked_room is not RoomEmpty
	
	root.visible = valid_room
	
	if not valid_room:
		return
	
	var world_position = clicked_room.get_top_center_position()
	var ui_position = Util.world_to_ui_position(world_position, self, camera)
	root.global_position = ui_position - Vector2(root.size.x / 2, root.size.y)
	
	room_name_label.text = clicked_room.name
	
	room_upgrade_hbox.visible = room.has_upgrades
	if room.has_upgrades:
		# keep index 0 as template, delete the rest
		for i in range(room_upgrade_hbox.get_child_count() - 1, 0, -1):
			room_upgrade_hbox.get_child(i).queue_free()

		var template = room_upgrade_hbox.get_child(0)
		template.visible = false

		# clone template for each upgrade
		for upgrade : RoomUpgrade in room.upgrades:
			var clone := template.duplicate()
			room_upgrade_hbox.add_child(clone)
			var content_root = clone.get_child(0).get_child(0)
			content_root.get_child(0).text = upgrade.name
			content_root.get_child(1).texture = upgrade.icon
			content_root.get_child(2).text = str(upgrade.cost, " $")
			clone.pressed.connect(room.try_set_upgrade.bind(upgrade))
			clone.modulate = Color.WHITE if upgrade == room.current_upgrade else Color.WEB_GRAY
			clone.show()

func _on_delete_room_clicked():
	if room == null:
		return
		
	Global.Building.delete_room(room)
