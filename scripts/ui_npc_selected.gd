extends FullscreenDragable
class_name UISelectionPanel

@onready var header_label = $MarginContainer/MarginContainer/VBoxContainer/Label
@onready var describtion_label = $MarginContainer/MarginContainer/VBoxContainer/DescribtionLabel
@onready var line : PixelLine = $LineAnchor/Line
@onready var need_ui_dummy = $MarginContainer/MarginContainer/VBoxContainer/NeedDummy
@onready var status_icon_label_dummy: Label = $MarginContainer/MarginContainer/VBoxContainer/StatusIconLabelDummy
@onready var status_row_dummy: MarginContainer = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer_Status
@onready var room_upgrade_hbox = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer/UpgradeSelection
@onready var room_delete_button = $MarginContainer/MarginContainer/VBoxContainer/Button
@onready var arrest_button = $MarginContainer/MarginContainer/VBoxContainer/ArrestButton
@onready var wanted_item_container = $MarginContainer/MarginContainer/VBoxContainer/WantedContainer
@onready var wanted_item_dummy = $MarginContainer/MarginContainer/VBoxContainer/WantedContainer/MarginContainer

const PrisonerItemScene = preload("res://scenes/ui/prisoner_item_ui.tscn")

var target = null
var needs = null
var need_ui_instances = []
var wanted_item_instances = []
var prisoner_item_instances = []
var status_icon_row = null
var _current_status_labels: Array = []
var _status_row_instance = null

var selected_room_highlight_instance
var selected_npc_highlight_instance

func _ready():
	super._ready()
	describtion_label.bbcode_enabled = true
	HoverHandler.click_hovered_node_signal.connect(_on_click_hovered_node_signal)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_potential_target_deleted)
	NPCEventHandler.on_destroy_npc_signal.connect(_on_potential_target_deleted)

	hide()
	need_ui_dummy.hide()
	status_icon_label_dummy.hide()
	status_row_dummy.hide()
	wanted_item_dummy.hide()
	arrest_button.hide()

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
	if is_instance_valid(status_icon_row):
		status_icon_row.queue_free()
	status_icon_row = null
	_current_status_labels = []

	if is_instance_valid(_status_row_instance):
		_status_row_instance.queue_free()
	_status_row_instance = null

	for n in need_ui_instances:
		n.queue_free()
	need_ui_instances.clear()

	for w in wanted_item_instances:
		w.queue_free()
	wanted_item_instances.clear()
	wanted_item_container.hide()

	for p in prisoner_item_instances:
		if is_instance_valid(p):
			p.queue_free()
	prisoner_item_instances.clear()

func _get_status_icon_entries(npc: NPC) -> Array:
	var entries = []
	var b = npc.Behaviour.behaviour_instance
	if b is KnockedOutBehaviour:
		entries.append({icon = UiNotifications.ICON_KNOCKED_OUT, label = "Knocked out"})
	if b is FightBehaviour or b is StopFightBehaviour:
		entries.append({icon = UiNotifications.ICON_FIGHT, label = "Fighting"})
	if npc is NPCGuest:
		var guest := npc as NPCGuest
		if guest.pending_arrest:
			entries.append({icon = UiNotifications.ICON_HANDCUFFS, label = "Marked for Arrest"})
		if b is ArrestedBehaviour:
			entries.append({icon = UiNotifications.ICON_HANDCUFFS, label = "Arrested"})
		if npc.look_info != null and WantedHandler.npc_bounties.has(npc.look_info):
			entries.append({icon = UiNotifications.ICON_FUGITIVE, label = "Has Bounty"})
	return entries

func _rebuild_status_icons(entries: Array):
	if is_instance_valid(status_icon_row):
		status_icon_row.queue_free()
	status_icon_row = null

	if entries.is_empty():
		return

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	var parent = need_ui_dummy.get_parent()
	parent.add_child(container)
	parent.move_child(container, describtion_label.get_index() + 1)
	status_icon_row = container

	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		container.add_child(row)

		var tex_rect := TextureRect.new()
		tex_rect.texture = entry.icon
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(16, 16)
		row.add_child(tex_rect)

		var lbl := status_icon_label_dummy.duplicate() as Label
		lbl.text = entry.label
		lbl.show()
		row.add_child(lbl)

func _show_status_row(text: String, color: Color, link_target = null, link_text: String = ""):
	if is_instance_valid(_status_row_instance):
		_status_row_instance.queue_free()
	var instance := status_row_dummy.duplicate() as MarginContainer
	var parent = status_row_dummy.get_parent()
	parent.add_child(instance)
	parent.move_child(instance, status_row_dummy.get_index() + 1)
	instance.get_node("ColorRect").color = color
	instance.get_node("HBoxContainer/Label").text = str(" ", text)
	var btn := instance.get_node("HBoxContainer/Button") as Button
	if link_target != null:
		btn.text = link_text
		btn.show()
		btn.pressed.connect(func(): manually_select(link_target))
	else:
		btn.hide()
	instance.show()
	_status_row_instance = instance

func _show_for_worker(worker: NPCWorker):
	header_label.text = "Worker"
	describtion_label.text = str(worker.character_name, "\nThis worker can be dragged onto rooms in order to work there.\n\nSTR [color=cornflower_blue]%d[/color]  AGI [color=cornflower_blue]%d[/color]  INT [color=cornflower_blue]%d[/color]" % [int(worker.strength * 100), int(worker.agility * 100), int(worker.intelligence * 100)])
	describtion_label.show()
	room_delete_button.hide()
	arrest_button.hide()
	room_upgrade_hbox.get_parent().hide()
	needs = null
	var has_job = worker.current_job != Enum.Jobs.IDLE and is_instance_valid(worker.current_job_room)
	var job_color = Color.TRANSPARENT if has_job else Color.ORANGE
	var room_name = worker.current_job_room.data.room_name if has_job and worker.current_job_room.data != null else ""
	var job_text = str("Working at") if has_job else "No Job"
	_show_status_row(job_text, job_color, worker.current_job_room if has_job else null, room_name)

func _show_for_guest(guest: NPCGuest):
	header_label.text = "Guest"
	describtion_label.text = "This guest will stay around as long as he is satisfied with your saloons services.\n\nSTR [color=cornflower_blue]%d[/color]  AGI [color=cornflower_blue]%d[/color]  INT [color=cornflower_blue]%d[/color]" % [int(guest.strength * 100), int(guest.agility * 100), int(guest.intelligence * 100)]
	describtion_label.show()
	room_delete_button.hide()
	room_upgrade_hbox.get_parent().hide()

	arrest_button.show()
	Util.disconnect_all_pressed(arrest_button)
	arrest_button.pressed.connect(func():
		if is_instance_valid(guest) and not guest.pending_arrest:
			guest.pending_arrest = true
	)

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

	arrest_button.hide()
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

	if room.associated_job != null:
		if room.worker:
			_show_status_row("Worker", Color.TRANSPARENT, room.worker, room.worker.character_name)
			room.worker.Tint.add_outline(Color.WHITE, 20, self)
		else:
			_show_status_row("No Worker", Color.ORANGE)

	if room is RoomWantedBoard:
		_show_wanted_board()
	elif room is RoomPrison:
		_show_prison(room)

	if room.has_upgrades:
		_show_room_upgrades(room)
	else:
		room_upgrade_hbox.get_parent().hide()

func _show_prison(room: RoomPrison):
	for prisoner in room.prisoners:
		if not prisoner is NPCGuest:
			continue
		var bounty: int = WantedHandler.npc_bounties.get(prisoner.look_info, 0) if prisoner.look_info != null else 0
		var fine: int = WantedHandler.npc_fight_fines.get(prisoner.look_info, 0) if prisoner.look_info != null else 0
		var instance = PrisonerItemScene.instantiate()
		wanted_item_container.add_child(instance)
		prisoner_item_instances.append(instance)
		instance.init(prisoner, bounty, fine)
		instance.show()
	if room.prisoners.size() > 0:
		wanted_item_container.show()

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

	if target is NPC:
		var entries = _get_status_icon_entries(target)
		var labels = entries.map(func(e): return e.label)
		if labels != _current_status_labels:
			_current_status_labels = labels
			_rebuild_status_icons(entries)

	if target is NPCWorker:
		var worker := target as NPCWorker
		var has_job = worker.current_job != Enum.Jobs.IDLE and is_instance_valid(worker.current_job_room)
		if is_instance_valid(_status_row_instance):
			var lbl := _status_row_instance.get_node("HBoxContainer/Label") as Label
			var expected = " Working at" if has_job else " No Job"
			if lbl.text != expected:
				var job_color = Color(0.3, 0.8, 0.3, 0.35) if has_job else Color(1.0, 0.5, 0.0, 0.35)
				var room_name = worker.current_job_room.data.room_name if has_job and worker.current_job_room.data != null else ""
				_show_status_row("Working at" if has_job else "No Job", job_color, worker.current_job_room if has_job else null, room_name)
