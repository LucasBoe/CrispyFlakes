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
	
	if target is NPCGuest:
		header_label.text = "Guest"
		
		needs = target.Needs
		
		for need : Need in needs.needs:
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
	
		var describtion = target.describtion
		describtion_label.visible = describtion != ""
		if describtion != "":
			describtion_label.text = describtion
	
		room_upgrade_hbox.get_parent().visible = target.has_upgrades
		if target.has_upgrades:
				
			# keep index 0 as template, delete the rest
			Util.delete_all_children_execept_index_0(room_upgrade_hbox)

			var template = room_upgrade_hbox.get_child(0)
			template.visible = false

			# clone template for each upgrade
			for upgrade : RoomUpgrade in target.upgrades:
				var clone := template.duplicate()
				room_upgrade_hbox.add_child(clone)
				var content_root = clone.get_child(0).get_child(0)
				content_root.get_child(0).text = upgrade.name
				content_root.get_child(1).text = str("+", upgrade.price, " $")
				content_root.get_child(2).texture = upgrade.icon
				content_root.get_child(3).text = str("-", upgrade.cost, " $")
				clone.pressed.connect(target.try_set_upgrade.bind(upgrade))
				clone.pressed.connect(refresh_upgrades)
				clone.show()
			
			refresh_upgrades()
			
	else:	
		room_upgrade_hbox.get_parent().hide()
	
	#self.size = self.get_combined_minimum_size()
	show()
	
func refresh_upgrades():
	for child in room_upgrade_hbox.get_children():
		var name = child.get_child(0).get_child(0).get_child(0).text
		child.modulate = Color.WHITE if name == target.current_upgrade.name else Color.WEB_GRAY

	
func _process(delta):
	super._process(delta)
	
	if not target:
		return
		
	var pos = Util.world_to_ui_position(target.global_position - Vector2(0, 12), self, %Camera)		
	line.target_position = pos
