extends FullscreenDragable
class_name UISelectionPanel

@onready var header_label = $MarginContainer/MarginContainer/VBoxContainer/Label
@onready var describtion_label = $MarginContainer/MarginContainer/VBoxContainer/DescribtionLabel
@onready var line : PixelLine = $LineAnchor/Line
@onready var need_ui_dummy = $MarginContainer/MarginContainer/VBoxContainer/NeedDummy
@onready var status_icon_label_dummy: Label = $MarginContainer/MarginContainer/VBoxContainer/StatusIconLabelDummy
@onready var status_row_dummy: MarginContainer = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer_Status
@onready var room_delete_button = $MarginContainer/MarginContainer/VBoxContainer/Button
@onready var hire_guest_button: Button = $MarginContainer/MarginContainer/VBoxContainer/HireGuestButton
@onready var arrest_button = $MarginContainer/MarginContainer/VBoxContainer/ArrestButton
@onready var worker_fight_response_row: HBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/WorkerFightResponseRow
@onready var worker_conflict_label: Label = $MarginContainer/MarginContainer/VBoxContainer/WorkerFightResponseRow/ConflictLabel
@onready var worker_conflict_button: Button = $MarginContainer/MarginContainer/VBoxContainer/WorkerFightResponseRow/ConflictButton
@onready var bounty_item_container = $MarginContainer/MarginContainer/VBoxContainer/BountyContainer
@onready var bounty_item_dummy = $MarginContainer/MarginContainer/VBoxContainer/BountyContainer/MarginContainer
@onready var storage_filter_container = $MarginContainer/MarginContainer/VBoxContainer/StorageFilterContainer
@onready var storage_filter_grid = $MarginContainer/MarginContainer/VBoxContainer/StorageFilterContainer/StorageFilterGrid
@onready var storage_filter_button_dummy: Button = $MarginContainer/MarginContainer/VBoxContainer/StorageFilterContainer/StorageFilterGrid/StorageFilterButtonDummy
@onready var prisoner_item_dummy: PrisonerItemUI = $MarginContainer/MarginContainer/VBoxContainer/BountyContainer/PrisonerItemDummy
@onready var call_sheriff_button: Button = $MarginContainer/MarginContainer/VBoxContainer/CallSheriffButton
@onready var dig_deeper_button: Button = $MarginContainer/MarginContainer/VBoxContainer/DigDeeperButton
@onready var status_icon_container_dummy: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/StatusIconContainerDummy
@onready var status_icon_row_dummy: HBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/StatusIconRowDummy
@onready var room_money_label: Label = $MarginContainer/MarginContainer/VBoxContainer/RoomMoneyLabel
@onready var room_module_ui: UISelectionRoomModules = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer
@onready var room_recipe_row: HBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/RoomRecipeRow
@onready var room_recipe_consumed_icon: TextureRect = $MarginContainer/MarginContainer/VBoxContainer/RoomRecipeRow/ConsumedIcon
@onready var room_recipe_arrow: Label = $MarginContainer/MarginContainer/VBoxContainer/RoomRecipeRow/ArrowLabel
@onready var room_recipe_produced_icon: TextureRect = $MarginContainer/MarginContainer/VBoxContainer/RoomRecipeRow/ProducedIcon

const _COIN_ATLAS = preload("res://assets/sprites/coins-sprite-sheet.png")

var target = null
var needs = null
var need_ui_instances = []
var bounty_item_instances = []
var prisoner_item_instances = []
var status_icon_row = null
var _current_status_labels: Array = []
var _status_row_instance = null

var selected_room_highlight_instance
var selected_npc_highlight_instance

var _npc_base_description: String = ""
var _npc_narrative_text: String = ""
var _satisfaction_log_container: VBoxContainer = null
var _satisfaction_log_size: int = -1
var _equipment_container: VBoxContainer = null

func _ready():
	super._ready()
	describtion_label.bbcode_enabled = true
	HoverHandler.click_hovered_node_signal.connect(_on_click_hovered_node_signal)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_potential_target_deleted)
	NPCEventHandler.on_destroy_npc_signal.connect(_on_potential_target_deleted)

	hide()
	need_ui_dummy.hide()
	status_icon_label_dummy.hide()
	status_icon_container_dummy.hide()
	status_icon_row_dummy.hide()
	status_row_dummy.hide()
	bounty_item_dummy.hide()
	prisoner_item_dummy.hide()
	call_sheriff_button.hide()
	dig_deeper_button.hide()
	storage_filter_button_dummy.hide()
	hire_guest_button.hide()
	arrest_button.hide()
	worker_fight_response_row.hide()

func manually_select(node):
	_on_click_hovered_node_signal(node)

func _on_click_hovered_node_signal(node):
	_clear_instances()

	if node == null:
		do_hide()
		return

	if is_instance_valid(selected_room_highlight_instance):
		RoomHighlighter.dispose(selected_room_highlight_instance)
	selected_room_highlight_instance = null

	if is_instance_valid(selected_npc_highlight_instance):
		selected_npc_highlight_instance.destroy()
	selected_npc_highlight_instance = null

	for npc_ref in Global.NPCSpawner.workers + Global.NPCSpawner.guests:
		if not is_instance_valid(npc_ref):
			continue
		var npc := npc_ref as NPC
		if npc == null:
			continue
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

	dig_deeper_button.hide()
	hire_guest_button.hide()
	_npc_base_description = ""
	_npc_narrative_text = ""

	room_money_label.hide()
	room_recipe_row.hide()
	room_module_ui.hide()

	for n in need_ui_instances:
		n.queue_free()
	need_ui_instances.clear()

	for w in bounty_item_instances:
		w.queue_free()
	bounty_item_instances.clear()
	bounty_item_container.hide()
	call_sheriff_button.hide()
	call_sheriff_button.disabled = false

	for p in prisoner_item_instances:
		if is_instance_valid(p):
			p.queue_free()
	prisoner_item_instances.clear()
	storage_filter_container.hide()

	if is_instance_valid(_satisfaction_log_container):
		_satisfaction_log_container.queue_free()
	_satisfaction_log_container = null
	_satisfaction_log_size = -1

	if is_instance_valid(_equipment_container):
		_equipment_container.queue_free()
	_equipment_container = null

func _get_status_icon_entries(npc: NPC) -> Array:
	return npc.get_state_icon_entries()

func _rebuild_status_icons(entries: Array):
	if is_instance_valid(status_icon_row):
		status_icon_row.queue_free()
	status_icon_row = null

	if entries.is_empty():
		return

	var container := status_icon_container_dummy.duplicate() as VBoxContainer
	var parent = need_ui_dummy.get_parent()
	parent.add_child(container)
	parent.move_child(container, describtion_label.get_index() + 1)
	container.show()
	status_icon_row = container

	for entry in entries:
		var row := status_icon_row_dummy.duplicate() as HBoxContainer
		container.add_child(row)
		if entry.has("icon"):
			row.get_child(0).texture = entry.icon
		var lbl := row.get_child(1) as Label
		lbl.text = entry.label
		row.show()

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
	header_label.text = worker.character_name
	_npc_base_description = str("This worker can be dragged onto rooms in order to work there.\n\nSTR [color=cornflower_blue]%d[/color]  AGI [color=cornflower_blue]%d[/color]  INT [color=cornflower_blue]%d[/color]" % [int(worker.strength * 100), int(worker.agility * 100), int(worker.intelligence * 100)])
	describtion_label.text = _npc_base_description
	describtion_label.show()
	room_delete_button.hide()
	hire_guest_button.hide()
	arrest_button.hide()
	worker_fight_response_row.show()
	_bind_worker_fight_response(worker)
	needs = null
	_rebuild_equipment_ui(worker)
	var has_job = worker.current_job != Enum.Jobs.IDLE and is_instance_valid(worker.current_job_room)
	var job_color = Color.TRANSPARENT if has_job else Color.ORANGE
	var room_name = worker.current_job_room.data.room_name if has_job and worker.current_job_room.data != null else ""
	var job_text = str("Working at") if has_job else "No Job"
	_show_status_row(job_text, job_color, worker.current_job_room if has_job else null, room_name)

func _show_for_guest(guest: NPCGuest):
	header_label.text = "Guest"
	_npc_base_description = "This guest will stay around as long as he is satisfied with your saloons services.\n\nSTR [color=cornflower_blue]%d[/color]  AGI [color=cornflower_blue]%d[/color]  INT [color=cornflower_blue]%d[/color]" % [int(guest.strength * 100), int(guest.agility * 100), int(guest.intelligence * 100)]
	describtion_label.text = _npc_base_description
	describtion_label.show()
	room_delete_button.hide()

	hire_guest_button.show()
	_bind_guest_hire_button(guest)
	arrest_button.show()
	_bind_guest_arrest_button(guest)
	worker_fight_response_row.hide()

	needs = guest.Needs
	_rebuild_equipment_ui(guest)
	_rebuild_satisfaction_log(guest)
	for need : Need in needs.needs:
		if need.type != Enum.Need.SATISFACTION \
		and need.type != Enum.Need.DRUNKENNESS \
		and need.type != Enum.Need.ENERGY \
		and need.type != Enum.Need.STAY_DURATION:
			continue
		var instance = need_ui_dummy.duplicate() as UINeedInfo
		need_ui_dummy.get_parent().add_child(instance)
		need_ui_instances.append(instance)
		instance.bind_instance(need)
		instance.show()

func _rebuild_satisfaction_log(guest: NPCGuest):
	if is_instance_valid(_satisfaction_log_container):
		_satisfaction_log_container.queue_free()
	_satisfaction_log_container = VBoxContainer.new()
	need_ui_dummy.get_parent().add_child(_satisfaction_log_container)
	_satisfaction_log_size = guest.satisfaction_log.size()

	var title := status_icon_label_dummy.duplicate() as Label
	title.text = "Satisfaction Log"
	title.show()
	_satisfaction_log_container.add_child(title)

	var by_reason: Dictionary = {}
	for entry in guest.satisfaction_log:
		var key: String = entry.reason if entry.reason != "" else "?"
		if by_reason.has(key):
			by_reason[key].amount += entry.amount
			by_reason[key].count += 1
		else:
			by_reason[key] = {amount = entry.amount, reason = key, count = 1}
	var collapsed: Array = by_reason.values()

	for entry in collapsed:
		var amount: float = entry.amount
		var lbl := status_icon_label_dummy.duplicate() as Label
		var sign_str: String = "+" if amount >= 0 else ""
		var count_str: String = " x%d" % entry.count if entry.count > 1 else ""
		lbl.text = "  %s%.2f  %s%s" % [sign_str, amount, entry.reason, count_str]
		lbl.add_theme_color_override("font_color", Color.LIGHT_GREEN if amount >= 0 else Color.SALMON)
		lbl.show()
		_satisfaction_log_container.add_child(lbl)

func _show_for_room(room: RoomBase):
	#needs = null

	hire_guest_button.hide()
	arrest_button.hide()
	worker_fight_response_row.hide()
	header_label.text = room.get_script().get_global_name().trim_prefix("Room")
	room_delete_button.disabled = false

	if room is RoomEmpty:
		room_delete_button.show()
		room_delete_button.disabled = true
	elif room is not RoomJunk and room is not RoomWell:
		room_delete_button.show()
		Util.disconnect_all_pressed(room_delete_button)
		room_delete_button.pressed.connect(func():
			Global.UI.confirm.show_dialogue(
				"You are about to delete a room and won't get the money back.",
				func():
					if is_instance_valid(room):
						Building.delete_room(room)
			)
		)
	else:
		room_delete_button.hide()

	selected_room_highlight_instance = RoomHighlighter.request_rect(room, Color.WHITE, 2, RoomHighlighter.Priority.SELECTION)

	var description = room.data.room_desc if room.data != null else ""
	describtion_label.visible = description != ""
	if description != "":
		describtion_label.text = description

	if room is RoomOuthouse:
		var outhouse := room as RoomOuthouse
		var fill_text = "Outhouse (%d/%d)" % [outhouse.uses, outhouse.get_max_uses()]
		if outhouse.is_full() and not room.worker:
			var has_cleaners = JobHandler.count_workers_in(Enum.Jobs.BROOM_CLEANER) > 0
			_show_status_row("Awaiting Cleaner" if has_cleaners else "No Cleaner", Color.DARK_GOLDENROD if has_cleaners else Color.ORANGE)
		else:
			var fill_color = Color.ORANGE if outhouse.is_full() else Color.TRANSPARENT
			_show_status_row(fill_text, fill_color)
	elif room is RoomEntertainment:
		var entertainment := room as RoomEntertainment
		if entertainment.worker:
			var module_name : String = entertainment.current_module.module_name if entertainment.current_module else "Act"
			var status_text := "%s Active (%d nearby guests)" % [module_name, entertainment.count_guests_in_range()]
			_show_status_row(status_text, Color.TRANSPARENT, entertainment.worker, entertainment.worker.character_name)
		else:
			_show_status_row("No Performer", Color.ORANGE)
	elif room is RoomWell:
		var well := room as RoomWell
		var water_text = "Water %d/%d" % [int(well.current_water), int(well.max_water)]
		var water_color = Color.ORANGE if not well.has_water() else Color.TRANSPARENT
		_show_status_row(water_text, water_color, well.worker if well.worker else null, well.worker.character_name if well.worker else "")
		dig_deeper_button.text = "Dig Deeper (%d$)" % well.get_dig_cost()
		dig_deeper_button.show()
		Util.disconnect_all_pressed(dig_deeper_button)
		dig_deeper_button.pressed.connect(func():
			dig_deeper_button.disabled = true
			if await well.dig_deeper():
				dig_deeper_button.text = "Dig Deeper (%d$)" % well.get_dig_cost()
			else:
				var btn_center = dig_deeper_button.global_position + dig_deeper_button.size / 2
				UiNotifications.create_notification_ui("not enough money", btn_center, null, Color.ORANGE)
			dig_deeper_button.disabled = false
		)
	elif room is RoomBed:
		var bed := room as RoomBed
		if bed.current_guests.size() > 0:
			var count = bed.current_guests.size()
			var capacity = bed._active_beds.size()
			var label = "Occupied (%d/%d)" % [count, capacity]
			_show_status_row(label, Color.TRANSPARENT, bed.current_guests[0], "Guest")
		elif bed.needs_cleaning:
			if room.worker:
				_show_status_row("Cleaning", Color.TRANSPARENT, room.worker, room.worker.character_name)
			else:
				var has_cleaners = JobHandler.count_workers_in(Enum.Jobs.BROOM_CLEANER) > 0
				_show_status_row("Awaiting Cleaner" if has_cleaners else "No Cleaner", Color.DARK_GOLDENROD if has_cleaners else Color.ORANGE)
		else:
			_show_status_row("Available", Color.TRANSPARENT)
	elif room is RoomBroomCloset:
		var closet := room as RoomBroomCloset
		var cleaners_text := "Cleaners %d/%d" % [closet.get_assigned_worker_count(), closet.get_job_capacity()]
		var broom_text := "%d/%d brooms issued" % [closet.issued_broom_count, RoomBroomCloset.MAX_CLEANERS]
		var status_text := "%s, %s" % [cleaners_text, broom_text]
		var status_color := Color.ORANGE if closet.get_assigned_worker_count() == 0 else Color.TRANSPARENT
		_show_status_row(status_text, status_color, closet.worker if closet.worker else null, closet.worker.character_name if closet.worker else "")
	elif room is RoomHorsePost:
		var post := room as RoomHorsePost
		var horse_text := "Horses %d/%d" % [post.get_horse_count(), post.get_max_horse_count()]
		_show_status_row(horse_text, Color.TRANSPARENT)
	elif room.associated_job != null:
		if room.worker:
			_show_status_row("Worker", Color.TRANSPARENT, room.worker, room.worker.character_name)
			room.worker.Tint.add_outline(Color.WHITE, 20, self)
		else:
			_show_status_row("No Worker", Color.ORANGE)

	room_money_label.visible = room.data != null and room.data.money_capacity > 0

	var d = room.data
	var has_recipe = d != null and (d.produces_item or d.has_consumed_item or d.produces_money)
	room_recipe_row.visible = has_recipe
	if has_recipe:
		_update_recipe_row(room)

	storage_filter_container.visible = false
	if room is RoomBountyBoard:
		_show_bounty_board()
	elif room is RoomPrison:
		_show_prison(room)
	elif room.get_script() != null and room.get_script().get_global_name() == "RoomStorage":
		_show_storage_filter(room)

	room_module_ui.populate(room)

func _show_storage_filter(room: RoomBase):
	storage_filter_container.visible = true
	Util.delete_all_children_execept_index_0(storage_filter_grid)
	for item_type in Enum.Items.values().filter(func(t): return t != Enum.Items.BROOM and t != Enum.Items.MONEY):
		var btn := storage_filter_button_dummy.duplicate() as Button
		var is_allowed: bool = item_type in room.allowed_items
		btn.button_pressed = is_allowed
		btn.icon = Item.get_info(item_type).Tex
		btn.tooltip_text = Enum.Items.keys()[item_type]
		var x_overlay := btn.get_node("XOverlay") as TextureRect
		x_overlay.visible = not is_allowed
		btn.toggled.connect(func(pressed: bool):
			x_overlay.visible = not pressed
			if pressed:
				if item_type not in room.allowed_items:
					room.allowed_items.append(item_type)
			else:
				room.allowed_items.erase(item_type)
		)
		storage_filter_grid.add_child(btn)
		btn.show()

func _show_prison(room: RoomPrison):
	for prisoner in room.prisoners:
		if not prisoner is NPCGuest:
			continue
		var bounty: int = BountyHandler.npc_bounties.get(prisoner.look_info, 0) if prisoner.look_info != null else 0
		var fine: int = BountyHandler.npc_fight_fines.get(prisoner, 0) if prisoner.look_info != null else 0
		var instance := prisoner_item_dummy.duplicate() as PrisonerItemUI
		bounty_item_container.add_child(instance)
		prisoner_item_instances.append(instance)
		instance.init(prisoner, bounty, fine)
		instance.show()
	if room.prisoners.size() > 0:
		bounty_item_container.show()
		call_sheriff_button.show()
		Util.disconnect_all_pressed(call_sheriff_button)
		call_sheriff_button.pressed.connect(func():
			Global.NPCSpawner.spawn_sheriff()
			call_sheriff_button.disabled = true
		)

func _show_bounty_board():
	var bounties = BountyHandler.get_all_bounties()
	for i in range(0, min(4, bounties.size())):
		var instance = bounty_item_dummy.duplicate() as BountyItemUI
		bounty_item_container.add_child(instance)
		bounty_item_instances.append(instance)
		instance.init(bounties[i])
		instance.show()
	bounty_item_container.show()

	var has_prison = Building.count_rooms_by_data(Building.room_data_prison) > 0
	call_sheriff_button.visible = not has_prison

	Util.disconnect_all_pressed(call_sheriff_button)
	call_sheriff_button.pressed.connect(func():
		Global.NPCSpawner.spawn_sheriff()
		call_sheriff_button.disabled = true
	)

func _update_recipe_row(room: RoomBase):
	var d = room.data
	if d == null:
		return
	if d.produces_money and room is RoomBar:
		var bar := room as RoomBar
		var has_module = bar.current_module != null
		room_recipe_consumed_icon.visible = has_module
		room_recipe_arrow.visible = has_module
		if has_module:
			room_recipe_consumed_icon.texture = bar.current_module.icon
		room_recipe_produced_icon.visible = true
		var coin_tex = AtlasTexture.new()
		coin_tex.atlas = _COIN_ATLAS
		coin_tex.region = Rect2(0, 0, 8, 8)
		room_recipe_produced_icon.texture = coin_tex
	else:
		room_recipe_consumed_icon.visible = d.has_consumed_item
		room_recipe_arrow.visible = d.has_consumed_item and d.produces_item
		room_recipe_produced_icon.visible = d.produces_item
		if d.has_consumed_item:
			room_recipe_consumed_icon.texture = Item.get_info(d.consumed_item_type).Tex
		if d.produces_item:
			room_recipe_produced_icon.texture = Item.get_info(d.produced_item_type).Tex

func _on_potential_target_deleted(room):
	if target == room:
		do_hide()

func do_hide():
	if is_instance_valid(selected_room_highlight_instance):
		RoomHighlighter.dispose(selected_room_highlight_instance)
	selected_room_highlight_instance = null

	if is_instance_valid(selected_npc_highlight_instance):
		selected_npc_highlight_instance.destroy()
	selected_npc_highlight_instance = null

	for npc_ref in Global.NPCSpawner.workers + Global.NPCSpawner.guests:
		if not is_instance_valid(npc_ref):
			continue
		var npc := npc_ref as NPC
		if npc == null:
			continue
		npc.Tint.remove_outline_for(self)

	hide()

func _bind_guest_arrest_button(guest: NPCGuest):
	if not is_instance_valid(guest):
		arrest_button.hide()
		return

	Util.disconnect_all_pressed(arrest_button)

	if guest.Behaviour.behaviour_instance is ArrestedBehaviour:
		arrest_button.text = "Arrested"
		arrest_button.disabled = true
		return

	arrest_button.disabled = false
	arrest_button.text = "Unmark Arrest" if guest.pending_arrest else "Mark for Arrest"
	arrest_button.pressed.connect(func():
		if not is_instance_valid(guest):
			return
		guest.pending_arrest = not guest.pending_arrest
		if guest.pending_arrest:
			FightHandler.try_start_auto_arrest(guest)
		_bind_guest_arrest_button(guest)
	)

func _bind_worker_fight_response(worker: NPCWorker) -> void:
	if not is_instance_valid(worker):
		worker_fight_response_row.hide()
		return

	Util.disconnect_all_pressed(worker_conflict_button)

	var is_fight := worker.saloon_fight_response == NPCWorker.SaloonFightResponse.FIGHT
	worker_conflict_label.text = "in conflict I"
	worker_conflict_button.text = "fight" if is_fight else "flee"
	worker_conflict_button.pressed.connect(func():
		if not is_instance_valid(worker):
			return
		worker.saloon_fight_response = NPCWorker.SaloonFightResponse.FLEE if is_fight else NPCWorker.SaloonFightResponse.FIGHT
		_bind_worker_fight_response(worker)
	)

func _rebuild_equipment_ui(npc: NPC) -> void:
	if is_instance_valid(_equipment_container):
		_equipment_container.queue_free()
	_equipment_container = null

	if npc.Equipment == null:
		return

	var parent: VBoxContainer = need_ui_dummy.get_parent()
	var container := VBoxContainer.new()
	parent.add_child(container)
	_equipment_container = container

	# WEAPON — inventory-backed, workers only
	if npc is NPCWorker:
		_add_weapon_inventory_row(container, npc as NPCWorker)

func _add_weapon_inventory_row(container: VBoxContainer, worker: NPCWorker) -> void:
	var inv: Node = get_node("/root/WeaponInventory")
	if inv == null:
		return

	var row := HBoxContainer.new()
	container.add_child(row)

	var lbl := status_icon_label_dummy.duplicate() as Label
	lbl.text = "Weapon:"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.show()
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.theme = hire_guest_button.theme
	opt.add_item("None")

	var current_inst = inv.get_equipped_by(worker)

	for inst in inv.instances:
		var entry_label: String = inst.data.weapon_name
		if inst == current_inst:
			entry_label += " *"
		elif not inst.is_available():
			entry_label += " (%s)" % inst.equipped_by.character_name
		var icon: Texture2D = inst.data.sprite
		if icon != null:
			opt.add_icon_item(icon, entry_label)
		else:
			opt.add_item(entry_label)

	if current_inst != null:
		var idx: int = inv.instances.find(current_inst)
		if idx >= 0:
			opt.selected = idx + 1

	opt.item_selected.connect(func(idx: int):
		if not is_instance_valid(worker):
			return
		var inv2: Node = get_node("/root/WeaponInventory")
		if inv2 == null:
			return
		if idx == 0:
			inv2.unequip(worker)
		else:
			inv2.equip(worker, inv2.instances[idx - 1])
		_rebuild_equipment_ui(worker)
	)
	row.add_child(opt)

	# Compact stats line for the equipped weapon
	if current_inst != null:
		var stats_lbl := status_icon_label_dummy.duplicate() as Label
		stats_lbl.text = "  " + current_inst.data.get_compact_stats()
		stats_lbl.show()
		container.add_child(stats_lbl)

func _bind_guest_hire_button(guest: NPCGuest):
	if not is_instance_valid(guest):
		hire_guest_button.hide()
		return

	Util.disconnect_all_pressed(hire_guest_button)
	hire_guest_button.disabled = false
	hire_guest_button.text = "Hire for 5$"
	hire_guest_button.pressed.connect(func():
		if not is_instance_valid(guest):
			return
		if not ResourceHandler.has_money(5):
			var btn_center = hire_guest_button.global_position + hire_guest_button.size / 2
			UiNotifications.create_notification_ui("not enough money", btn_center, null, Color.ORANGE)
			return

		hire_guest_button.disabled = true
		ResourceHandler.change_money(-5)
		var worker := Global.NPCSpawner.hire_guest_as_worker(guest)
		if is_instance_valid(worker):
			manually_select(worker)
	)

func _process(delta):
	super._process(delta)

	if not target:
		return

	var pos = Util.world_to_ui_position(target.global_position - Vector2(0, 12), self, Camera)
	line.target_position = pos

	if target is RoomWell and is_instance_valid(_status_row_instance):
		var well := target as RoomWell
		var water_text = "Water %d/%d" % [int(well.current_water), int(well.max_water)]
		_status_row_instance.get_node("HBoxContainer/Label").text = str(" ", water_text)
		var water_color = Color.ORANGE if not well.has_water() else Color.TRANSPARENT
		_status_row_instance.get_node("ColorRect").color = water_color

	if room_money_label.visible and target is RoomBase:
		var stored = MoneyHandler.get_money_at(Vector2i(target.x, target.y))
		var cap = target.data.money_capacity if target.data != null else 0
		room_money_label.text = str("Cash stored here: ", roundi(stored), " / ", cap, "$")

	if target is NPC:
		var entries = _get_status_icon_entries(target)
		var labels = entries.map(func(e): return e.label)
		if labels != _current_status_labels:
			_current_status_labels = labels
			_rebuild_status_icons(entries)

		var b = (target as NPC).Behaviour.behaviour_instance
		var narrative := b.get_narrative() if b != null else "..."
		if narrative != _npc_narrative_text:
			_npc_narrative_text = narrative
			describtion_label.text = _npc_base_description + "\n\n[color=#888888]" + narrative + "[/color]"

	if target is NPCGuest:
		_bind_guest_hire_button(target)
		_bind_guest_arrest_button(target)
		var guest := target as NPCGuest
		if guest.satisfaction_log.size() != _satisfaction_log_size:
			_rebuild_satisfaction_log(guest)

	if target is NPCWorker:
		var worker := target as NPCWorker
		_bind_worker_fight_response(worker)
		var has_job = worker.current_job != Enum.Jobs.IDLE and is_instance_valid(worker.current_job_room)
		if is_instance_valid(_status_row_instance):
			var lbl := _status_row_instance.get_node("HBoxContainer/Label") as Label
			var expected = " Working at" if has_job else " No Job"
			if lbl.text != expected:
				var job_color = Color(0.3, 0.8, 0.3, 0.35) if has_job else Color(1.0, 0.5, 0.0, 0.35)
				var room_name = worker.current_job_room.data.room_name if has_job and worker.current_job_room.data != null else ""
				_show_status_row("Working at" if has_job else "No Job", job_color, worker.current_job_room if has_job else null, room_name)
