extends FullscreenDragable
class_name UISelectionPanel

@onready var header_label = $MarginContainer/MarginContainer/VBoxContainer/Label
@onready var describtion_label = $MarginContainer/MarginContainer/VBoxContainer/DescribtionLabel
@onready var line : PixelLine = $LineAnchor/Line
@onready var need_ui_dummy = $MarginContainer/MarginContainer/VBoxContainer/NeedDummy
@onready var room_upgrade_hbox = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer/UpgradeSelection
@onready var room_delete_button = $MarginContainer/MarginContainer/VBoxContainer/Button
@onready var wanted_item_container = $MarginContainer/MarginContainer/VBoxContainer/WantedContainer
@onready var wanted_item_dummy = $MarginContainer/MarginContainer/VBoxContainer/WantedContainer/MarginContainer

var target = null
var needs = null
var need_ui_instances = []
var wanted_item_instances = []

var selected_room_highlight_instance
var selected_npc_highlight_instance

func _ready():
	super._ready()
	HoverHandler.click_hovered_node_signal.connect(_on_click_hovered_node_signal)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_potential_target_deleted)
	NPCEventHandler.on_destroy_npc_signal.connect(_on_potential_target_deleted)

	hide()
	need_ui_dummy.hide()
	wanted_item_dummy.hide()

func manually_select(node):
	_on_click_hovered_node_signal(node)

func _on_click_hovered_node_signal(node):
	_clear_instances()

	if node == null:
		do_hide()
		return

	if is_instance_valid(selected_room_highlight_instance):
		RoomHighlighter.dispose(selected_room_highlight_instance)

	if is_instance_valid(selected_npc_highlight_instance):
		selected_npc_highlight_instance.destroy()

	for npc : NPC in Global.NPCSpawner.workers + Global.NPCSpawner.guests:
		npc.Tint.remove_outline_for(self)

	target = node

	if target is NPC:
		selected_npc_highlight_instance = target.Tint.add_outline(Color.WHITE, 15, self)

	if target is NPCWorker:
		_show_for_worker(target)
	elif target is NPCGuest:
		_show_for_guest(target)
	elif target is RoomBase:
		_show_for_room(target)

	#self.size = self.get_combined_minimum_size()
	var parent = room_delete_button.get_parent()
	parent.move_child(room_delete_button, parent.get_child_count())
	show()

func _clear_instances():
	for n in need_ui_instances:
		n.queue_free()
	need_ui_instances.clear()

	for w in wanted_item_instances:
		w.queue_free()
	wanted_item_instances.clear()
	wanted_item_container.hide()

func _show_for_worker(worker: NPCWorker):
	header_label.text = "Worker"
	describtion_label.text = str(worker.character_name, "\nThis worker can be dragged onto rooms in order to work there.")
	describtion_label.show()
	room_delete_button.hide()
	room_upgrade_hbox.get_parent().hide()
	needs = null

func _show_for_guest(guest: NPCGuest):
	header_label.text = "Guest"
	describtion_label.text = "This guest will stay around as long as he is satisfied with your saloons services."
	describtion_label.show()
	room_delete_button.hide()
	room_upgrade_hbox.get_parent().hide()

	needs = guest.Needs
	for need : Need in needs.needs:
		if need.type != Enum.Need.SATISFACTION and need.type != Enum.Need.DRUNKENNESS:
			continue
		var instance = need_ui_dummy.duplicate() as UINeedInfo
		need_ui_dummy.get_parent().add_child(instance)
		need_ui_instances.append(instance)
		instance.bind_instance(need)
		instance.show()

func _show_for_room(room: RoomBase):
	#needs = null

	header_label.text = room.get_script().get_global_name().trim_prefix("Room")

	if room is not RoomJunk:
		room_delete_button.show()
		Util.disconnect_all_pressed(room_delete_button)
		room_delete_button.pressed.connect(func():
			Global.UI.confirm.show_dialogue(
				"You are about to delete a room and won't get the money back.",
				func():
					if is_instance_valid(room):
						Global.Building.delete_room(room)
			)
		)
	else:
		room_delete_button.hide()

	selected_room_highlight_instance = RoomHighlighter.request_rect(room, Color.WHITE)

	var description = room.data.room_desc if room.data != null else ""
	describtion_label.visible = description != ""
	if description != "":
		describtion_label.text = description

	if room.worker:
		room.worker.Tint.add_outline(Color.WHITE, 20, self)

	if room is RoomWantedBoard:
		_show_wanted_board()

	if room.has_upgrades:
		_show_room_upgrades(room)
	else:
		room_upgrade_hbox.get_parent().hide()

func _show_wanted_board():
	var wanted_npcs = WantedHandler.get_all_wanted_npcs()
	for i in range(0, min(4, wanted_npcs.size())):
		var instance = wanted_item_dummy.duplicate() as WantedItemUI
		wanted_item_container.add_child(instance)
		wanted_item_instances.append(instance)
		instance.init(wanted_npcs[i])
		instance.show()
	wanted_item_container.show()

func _show_room_upgrades(room: RoomBase):
	room_upgrade_hbox.get_parent().show()

	# keep index 0 as template, delete the rest
	Util.delete_all_children_execept_index_0(room_upgrade_hbox)

	var template = room_upgrade_hbox.get_child(0)
	template.visible = false

	var i = 0
	for upgrade : RoomUpgrade in room.upgrades:
		i += 1
		var clone := template.duplicate()
		room_upgrade_hbox.add_child(clone)
		var content_root = clone.get_child(0).get_child(0)

		var upgrade_root = content_root.get_child(0)
		upgrade_root.get_child(0).text = str(i, ".")
		upgrade_root.get_child(1).text = upgrade.upgrade_name
		upgrade_root.get_child(2).text = str("Cost: ", upgrade.upgrade_price, " $")
		upgrade_root.get_child(4).texture = upgrade.upgrade_preview

		var item_root = content_root.get_child(1)
		item_root.get_child(0).text = str("Sells: ", upgrade.item_name)
		item_root.get_child(1).get_child(0).texture = upgrade.item_icon
		item_root.get_child(1).get_child(1).text = str(upgrade.item_cost, "$")

		var required_label = item_root.get_child(2)
		if upgrade.room_required != null:
			required_label.text = str("needs\n", upgrade.room_required.room_name)
			required_label.show()
		else:
			required_label.hide()

		clone.pressed.connect(room.try_set_upgrade.bind(upgrade))
		clone.pressed.connect(refresh_upgrades)
		clone.show()

	refresh_upgrades()

func refresh_upgrades():
	for child in room_upgrade_hbox.get_children():
		var upgrade_name = child.get_child(0).get_child(0).get_child(0).get_child(1).text
		var price_label = child.get_child(0).get_child(0).get_child(0).get_child(2) as Label
		var current_label = child.get_child(0).get_child(0).get_child(0).get_child(3) as Label
		var is_current = upgrade_name == target.current_upgrade.upgrade_name
		child.modulate = Color.WHITE if not is_current else Color.WEB_GRAY
		price_label.visible = not is_current
		current_label.visible = is_current

func _on_potential_target_deleted(room):
	if target == room:
		do_hide()

func do_hide():
	if is_instance_valid(selected_room_highlight_instance):
		RoomHighlighter.dispose(selected_room_highlight_instance)

	if is_instance_valid(selected_npc_highlight_instance):
		selected_npc_highlight_instance.destroy()

	for npc : NPC in Global.NPCSpawner.workers + Global.NPCSpawner.guests:
		npc.Tint.remove_outline_for(self)

	hide()

func _process(delta):
	super._process(delta)

	if not target:
		return

	var pos = Util.world_to_ui_position(target.global_position - Vector2(0, 12), self, %Camera)
	line.target_position = pos
