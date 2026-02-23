extends FullscreenDragable

@onready var header_label = $MarginContainer/MarginContainer/VBoxContainer/Label
@onready var describtion_label = $MarginContainer/MarginContainer/VBoxContainer/DescribtionLabel
@onready var line : PixelLine = $LineAnchor/Line
@onready var need_ui_dummy = $MarginContainer/MarginContainer/VBoxContainer/NeedDummy
@onready var room_upgrade_hbox = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer/UpgradeSelection
@onready var room_delete_button = $MarginContainer/MarginContainer/VBoxContainer/Button

var target = null
var needs = null

var need_ui_instances = []

func _ready():
	super._ready()
	HoverHandler.click_hovered_node_signal.connect(_on_click_hovered_node_signal)
	hide()
	need_ui_dummy.hide()
	
func _on_click_hovered_node_signal(node):
	
	for n in need_ui_instances:
		n.queue_free()
	
	need_ui_instances.clear()
	
	if node == null:
		hide()
		return
		
	target = node
	
	if target is NPCWorker:
		header_label.text = "Worker"
		describtion_label.text = str((target as NPCWorker).character_name,"\nThis worker can be dragged onto rooms in order to work there.")
		describtion_label.show()
		room_delete_button.hide()
	
	if target is NPCGuest:
		header_label.text = "Guest"
		describtion_label.text = "This guest will stay around as long as he is satisfied with your saloons services."
		describtion_label.show()
		room_delete_button.hide()
		
		needs = target.Needs
		
		for need : Need in needs.needs:
			if need.type != Enum.Need.SATISFACTION and need.type != Enum.Need.DRUNKENNESS:
				continue
			
			var instance = need_ui_dummy.duplicate() as UINeedInfo
			need_ui_dummy.get_parent().add_child(instance)
			need_ui_instances.append(instance)
			instance.bind_instance(need)
			instance.show()
			
	else:
		needs = null
		
	if target is RoomBase:
		header_label.text = target.get_script().get_global_name().trim_prefix("Room")
		room_delete_button.visible = target is not RoomJunk
		room_delete_button.pressed.connect(Global.UI.confirm.show_dialogue.bind("You are about to delete a room and won't get the money back.", Global.Building.delete_room.bind(target)))
	
		var describtion = target.data.room_desc if target.data != null else ""
		describtion_label.visible = describtion != ""
		if describtion != "":
			describtion_label.text = describtion
	
		room_upgrade_hbox.get_parent().visible = target.has_upgrades
		if target.has_upgrades:
				
			# keep index 0 as template, delete the rest
			Util.delete_all_children_execept_index_0(room_upgrade_hbox)

			var template = room_upgrade_hbox.get_child(0)
			template.visible = false
			
			var i = 0

			# clone template for each upgrade
			for upgrade : RoomUpgrade in target.upgrades:
				i+=1
				var clone := template.duplicate()
				room_upgrade_hbox.add_child(clone)
				var content_root = clone.get_child(0).get_child(0)
				
				var upgrade_root = content_root.get_child(0)
				upgrade_root.get_child(0).text = str(i,".")
				upgrade_root.get_child(1).text = upgrade.upgrade_name
				upgrade_root.get_child(2).text = str("Cost: ", upgrade.upgrade_price, " $")
				upgrade_root.get_child(4).texture = upgrade.upgrade_preview
				
				var item_root = content_root.get_child(1)
				item_root.get_child(0).text = str("Sells: ", upgrade.item_name)
				item_root.get_child(1).get_child(0).texture = upgrade.item_icon
				item_root.get_child(1).get_child(1).text = str(upgrade.item_cost, "$")
				
				clone.pressed.connect(target.try_set_upgrade.bind(upgrade))
				clone.pressed.connect(refresh_upgrades)
				clone.show()
			
			refresh_upgrades()
			
	else:	
		room_upgrade_hbox.get_parent().hide()
	
	#self.size = self.get_combined_minimum_size()
	var parent = room_delete_button.get_parent()
	parent.move_child(room_delete_button, parent.get_child_count())
	show()
	
func refresh_upgrades():
	for child in room_upgrade_hbox.get_children():
		var name = child.get_child(0).get_child(0).get_child(0).get_child(1).text
		var price_label = child.get_child(0).get_child(0).get_child(0).get_child(2) as Label
		var current_label = child.get_child(0).get_child(0).get_child(0).get_child(3) as Label
		var is_current = name == target.current_upgrade.upgrade_name
		child.modulate = Color.WHITE if not is_current else Color.WEB_GRAY
		price_label.visible = not is_current
		current_label.visible = is_current
	
func _process(delta):
	super._process(delta)
	
	if not target:
		return
		
	var pos = Util.world_to_ui_position(target.global_position - Vector2(0, 12), self, %Camera)		
	line.target_position = pos
