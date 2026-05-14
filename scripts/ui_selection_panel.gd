extends FullscreenDragable
class_name UISelectionPanel

const ROOM_TRADING_OFFICE_SCRIPT = preload("res://scripts/room_trading_office.gd")

@onready var header_label = $MarginContainer/MarginContainer/VBoxContainer/HeaderRow/Label
@onready var panel_close_button: Button = $MarginContainer/MarginContainer/VBoxContainer/HeaderRow/CloseButton
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
@onready var gambling_ui: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI
@onready var gambling_host_state: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/HostState
@onready var gambling_new_round_button: Button = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/HostState/NewRoundButton
@onready var gambling_setup_state: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/SetupState
@onready var gambling_selected_jackpot_label: Label = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/SetupState/SelectedJackpotLabel
@onready var gambling_setup_loop_toggle: CheckBox = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/SetupState/LoopToggle
@onready var gambling_start_round_button: Button = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/SetupState/StartRoundButton
@onready var gambling_active_state: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/ActiveState
@onready var gambling_round_status_label: Label = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/ActiveState/RoundStatusLabel
@onready var gambling_round_progress_bar: ProgressBar = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/ActiveState/RoundProgressBar
@onready var gambling_watcher_label: Label = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/ActiveState/WatcherLabel
@onready var gambling_round_detail_label: Label = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/ActiveState/RoundDetailLabel
@onready var gambling_active_loop_toggle: CheckBox = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/ActiveState/LoopToggle
@onready var gambling_summary_state: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/SummaryState
@onready var gambling_summary_host_button: Button = $MarginContainer/MarginContainer/VBoxContainer/GamblingUI/SummaryState/HostNewRoundButton
@onready var trading_office_ui = $MarginContainer/MarginContainer/VBoxContainer/TradingOfficeUI
@onready var satisfaction_log_section: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/SatisfactionLogSection
@onready var satisfaction_log_toggle_button: Button = $MarginContainer/MarginContainer/VBoxContainer/SatisfactionLogSection/SatisfactionLogToggleButton
@onready var satisfaction_log_items: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/SatisfactionLogSection/SatisfactionLogItems
@onready var narrative_label: RichTextLabel = $MarginContainer/MarginContainer/VBoxContainer/NarrativeLabel

const _COIN_ATLAS = preload("res://assets/sprites/coins-sprite-sheet.png")
const _ROOM_TILE_SIZE := 48.0
const _NPC_SELECTION_OFFSET := Vector2(0, -12)
const _PANEL_TARGET_GAP := 96.0
const _PANEL_SCREEN_MARGIN := 8.0

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

var _connection_line: PixelLine = null

var _npc_base_description: String = ""
var _npc_narrative_text: String = ""
var _trait_container: VBoxContainer = null
var _satisfaction_log_size: int = -1
var _is_satisfaction_log_expanded := true
var _equipment_container: VBoxContainer = null
var _storage_items_container: VBoxContainer = null
var _storage_items_signature: Array = []
var _gambling_signature: String = ""
var _manual_follow_offset := Vector2.ZERO
var _follow_side: int = 0
var _context_menu_blocked := false
var _gambling_jackpot_buttons: Array[Button] = []
var _gambling_summary_rows: Dictionary = {}

func _ready():
	super._ready()
	describtion_label.bbcode_enabled = true
	narrative_label.bbcode_enabled = true
	HoverHandler.click_hovered_node_signal.connect(_on_click_hovered_node_signal)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_potential_target_deleted)
	NPCEventHandler.on_destroy_npc_signal.connect(_on_potential_target_deleted)

	panel_close_button.pressed.connect(do_hide)
	satisfaction_log_toggle_button.pressed.connect(_on_satisfaction_log_toggle_pressed)
	gambling_new_round_button.pressed.connect(_on_gambling_new_round_pressed)
	gambling_start_round_button.pressed.connect(_on_gambling_start_round_pressed)
	gambling_setup_loop_toggle.toggled.connect(_on_gambling_setup_loop_toggled)
	gambling_active_loop_toggle.toggled.connect(_on_gambling_active_loop_toggled)
	gambling_summary_host_button.pressed.connect(_on_gambling_summary_host_pressed)
	_gambling_jackpot_buttons = [
		gambling_ui.get_node("SetupState/JackpotGrid/Jackpot20Button") as Button,
		gambling_ui.get_node("SetupState/JackpotGrid/Jackpot50Button") as Button,
		gambling_ui.get_node("SetupState/JackpotGrid/Jackpot100Button") as Button,
		gambling_ui.get_node("SetupState/JackpotGrid/Jackpot250Button") as Button,
		gambling_ui.get_node("SetupState/JackpotGrid/Jackpot500Button") as Button,
		gambling_ui.get_node("SetupState/JackpotGrid/Jackpot1000Button") as Button,
	]
	for i in range(_gambling_jackpot_buttons.size()):
		var jackpot := RoomGambling.JACKPOT_OPTIONS[i]
		_gambling_jackpot_buttons[i].pressed.connect(_on_gambling_jackpot_selected.bind(jackpot))
	_gambling_summary_rows = {
		jackpot = gambling_ui.get_node("SummaryState/JackpotRow") as HBoxContainer,
		fees = gambling_ui.get_node("SummaryState/FeesRow") as HBoxContainer,
		player_wins = gambling_ui.get_node("SummaryState/PlayerWinsRow") as HBoxContainer,
		cheating = gambling_ui.get_node("SummaryState/CheatingRow") as HBoxContainer,
		returned = gambling_ui.get_node("SummaryState/ReturnedRow") as HBoxContainer,
		net_result = gambling_ui.get_node("SummaryState/NetResultRow") as HBoxContainer,
	}

	_connection_line = PixelLine.new()
	_connection_line.line_color = Color(1.0, 1.0, 0.5, 0.7)
	_connection_line.line_width = 2
	_connection_line.z_index = 2190
	_connection_line.z_as_relative = false
	Building.add_child(_connection_line)
	_connection_line.hide()

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
	satisfaction_log_section.hide()
	satisfaction_log_items.hide()
	narrative_label.hide()
	gambling_ui.hide()

func manually_select(node):
	_on_click_hovered_node_signal(node)

func set_context_menu_blocked(blocked: bool) -> void:
	_context_menu_blocked = blocked
	if blocked:
		do_hide()

func _on_click_hovered_node_signal(node):
	if _context_menu_blocked:
		do_hide()
		return

	_clear_instances()

	if node == null:
		do_hide()
		return

	if is_instance_valid(selected_room_highlight_instance):
		RoomHighlighter.dispose(selected_room_highlight_instance)
	selected_room_highlight_instance = null
	_clear_selected_room_outline()

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
	_manual_follow_offset = Vector2.ZERO
	_follow_side = 0

	if target is NPC:
		selected_npc_highlight_instance = target.Tint.add_outline(Color.WHITE, 15, self)

	if target is NPCWorker:
		_show_for_worker(target)
	elif target is NPCGuest:
		_show_for_guest(target)
	elif target is RoomBase:
		_show_for_room(target)

	#self.size = self.get_combined_minimum_size()
	_keep_bottom_items_last()
	show()
	_update_floating_panel_position()
	call_deferred("_update_floating_panel_position")

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
	narrative_label.hide()
	narrative_label.text = ""
	_npc_base_description = ""
	_npc_narrative_text = ""
	_is_satisfaction_log_expanded = true

	if is_instance_valid(_trait_container):
		_trait_container.queue_free()
	_trait_container = null

	room_money_label.hide()
	room_recipe_row.hide()
	room_module_ui.hide()
	trading_office_ui.clear_room()

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

	satisfaction_log_section.hide()
	_clear_satisfaction_log_items()
	_satisfaction_log_size = -1

	if is_instance_valid(_equipment_container):
		_equipment_container.queue_free()
	_equipment_container = null

	if is_instance_valid(_storage_items_container):
		_storage_items_container.queue_free()
	_storage_items_container = null
	_storage_items_signature = []

	gambling_ui.hide()
	gambling_host_state.hide()
	gambling_setup_state.hide()
	gambling_active_state.hide()
	gambling_summary_state.hide()
	_gambling_signature = ""

	_connection_line.hide()

func _keep_bottom_items_last() -> void:
	var parent = room_delete_button.get_parent()
	parent.move_child(room_delete_button, parent.get_child_count())
	parent.move_child(satisfaction_log_section, parent.get_child_count())
	parent.move_child(narrative_label, parent.get_child_count())

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
	if target is RoomGambling:
		parent.move_child(instance, describtion_label.get_index() + 1)
	else:
		parent.move_child(instance, status_row_dummy.get_index() + 1)
	instance.get_node("ColorRect").color = color
	var label := instance.get_node("HBoxContainer/Label") as Label
	label.text = str(" ", text)
	var font_color := _get_status_row_font_color(color)
	label.add_theme_color_override("font_color", font_color)
	var btn := instance.get_node("HBoxContainer/Button") as Button
	_set_status_row_button_color(btn, font_color)
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
	_npc_base_description = "This worker can be dragged onto rooms in order to work there."
	describtion_label.text = _npc_base_description
	describtion_label.show()
	_rebuild_traits_ui(worker)
	room_delete_button.hide()
	hire_guest_button.hide()
	arrest_button.hide()
	worker_fight_response_row.show()
	_position_worker_fight_response_row()
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
	_npc_base_description = "This guest will stay around as long as he is satisfied with your saloons services."
	describtion_label.text = _npc_base_description
	describtion_label.show()
	_rebuild_traits_ui(guest)
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

func _rebuild_traits_ui(npc: NPC) -> void:
	if is_instance_valid(_trait_container):
		_trait_container.queue_free()
	_trait_container = null

	if npc.Traits == null or npc.Traits.traits.is_empty():
		return

	var parent: VBoxContainer = need_ui_dummy.get_parent()
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	parent.add_child(container)
	parent.move_child(container, describtion_label.get_index() + 1)
	_trait_container = container

	var title := status_icon_label_dummy.duplicate() as Label
	title.text = "Traits"
	title.show()
	container.add_child(title)

	for data in npc.Traits.traits:
		container.add_child(_create_trait_row(data))

func _position_worker_fight_response_row() -> void:
	var parent := worker_fight_response_row.get_parent()
	var anchor: Control = _trait_container if is_instance_valid(_trait_container) else describtion_label
	parent.move_child(worker_fight_response_row, anchor.get_index() + 1)

func _create_trait_row(data) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.55, 0.18, 0.24) if data.is_positive() else Color(0.75, 0.24, 0.22, 0.24)
	style.content_margin_left = 4
	style.content_margin_top = 2
	style.content_margin_right = 4
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	panel.add_child(text_box)

	var name_label := status_icon_label_dummy.duplicate() as Label
	name_label.text = data.trait_name
	name_label.add_theme_color_override("font_color", Color(0.72, 0.95, 0.45) if data.is_positive() else Color(1.0, 0.55, 0.52))
	name_label.show()
	text_box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.theme = status_icon_label_dummy.theme
	desc_label.text = data.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.77, 0.9))
	text_box.add_child(desc_label)
	return panel

func _rebuild_satisfaction_log(guest: NPCGuest):
	_satisfaction_log_size = guest.satisfaction_log.size()
	_clear_satisfaction_log_items()

	if guest.satisfaction_log.is_empty():
		satisfaction_log_section.hide()
		satisfaction_log_items.hide()
		return

	satisfaction_log_section.show()

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
		satisfaction_log_items.add_child(lbl)

	_update_satisfaction_log_ui()

func _clear_satisfaction_log_items() -> void:
	for child in satisfaction_log_items.get_children():
		satisfaction_log_items.remove_child(child)
		child.queue_free()

func _update_satisfaction_log_ui() -> void:
	var has_entries := satisfaction_log_items.get_child_count() > 0
	satisfaction_log_section.visible = has_entries
	satisfaction_log_toggle_button.text = "v Satisfaction Log" if _is_satisfaction_log_expanded else "> Satisfaction Log"
	satisfaction_log_items.visible = has_entries and _is_satisfaction_log_expanded

func _on_satisfaction_log_toggle_pressed() -> void:
	if not satisfaction_log_section.visible:
		return
	_is_satisfaction_log_expanded = not _is_satisfaction_log_expanded
	_update_satisfaction_log_ui()

func _show_for_room(room: RoomBase):
	#needs = null

	hire_guest_button.hide()
	arrest_button.hide()
	worker_fight_response_row.hide()
	header_label.text = room.data.room_name if room.data != null and room.data.room_name != "" else room.get_script().get_global_name().trim_prefix("Room")
	room_delete_button.text = "Delete Room"
	room_delete_button.disabled = false

	if room is RoomEmpty:
		var room_above = Building.get_room_from_index(Vector2i(room.x, room.y + 1))
		var can_erase = room_above == null or room_above is RoomEmpty
		room_delete_button.show()
		room_delete_button.disabled = not can_erase
		if can_erase:
			Util.disconnect_all_pressed(room_delete_button)
			room_delete_button.pressed.connect(func():
				if is_instance_valid(room):
					Building.erase_empty(room)
					hide()
			)
	elif room is not RoomJunk and room is not RoomWell:
		room_delete_button.show()
		if room.has_method("can_delete") and not room.can_delete():
			room_delete_button.text = "Round Active"
			room_delete_button.disabled = true
		else:
			room_delete_button.disabled = false
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
	room.set_outline(true, self)

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
	elif room is RoomWaterTower:
		var tower := room as RoomWaterTower
		var water_text := "Water %d/%d" % [int(tower.current_water), int(RoomWaterTower.MAX_WATER)]
		var water_color: Color = Color.ORANGE if not tower.has_water() else Color.TRANSPARENT
		_show_status_row(water_text, water_color, tower.worker if tower.worker else null, tower.worker.character_name if tower.worker else "")
		if tower.worker:
			tower.worker.Tint.add_outline(Color.WHITE, 20, self)

		dig_deeper_button.text = "Raise Tower  (%d$)" % tower.RAISE_COST
		dig_deeper_button.disabled = not tower.can_raise()
		dig_deeper_button.show()
		Util.disconnect_all_pressed(dig_deeper_button)
		dig_deeper_button.pressed.connect(func():
			dig_deeper_button.disabled = true
			if not await tower.raise_tower():
				var btn_center = dig_deeper_button.global_position + dig_deeper_button.size / 2
				UiNotifications.create_notification_ui("not enough money", btn_center, null, Color.ORANGE)
			dig_deeper_button.disabled = not tower.can_raise()
		)

	elif room is RoomStove:
		_update_stove_status(room as RoomStove)
	elif room is RoomGambling:
		_update_gambling_status(room as RoomGambling)
		_rebuild_gambling_ui(room as RoomGambling, true)
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
	elif room is RoomStorage:
		_show_storage_filter(room as RoomStorage)

	if room.get_script() == ROOM_TRADING_OFFICE_SCRIPT:
		trading_office_ui.bind_room(room)

	room_module_ui.populate(room)

func _update_stove_status(stove: RoomStove) -> void:
	if not is_instance_valid(stove):
		return

	for npc_ref in Global.NPCSpawner.workers + Global.NPCSpawner.guests:
		if not is_instance_valid(npc_ref):
			continue
		var npc := npc_ref as NPC
		if npc != null:
			npc.Tint.remove_outline_for(self)

	var status_text := ""
	var status_color := Color.TRANSPARENT
	if stove.get_fuel_seconds_remaining() > 0.0:
		status_text = "Heating (%ds fuel left)" % int(ceili(stove.get_fuel_seconds_remaining()))
	elif stove.get_ember_seconds_remaining() > 0.0:
		status_text = "Cooling Down"
		status_color = Color.DARK_GOLDENROD
	else:
		status_text = "Out of Wood"
		status_color = Color.ORANGE

	if is_instance_valid(stove.worker):
		stove.worker.Tint.add_outline(Color.WHITE, 20, self)
		_set_stove_status_row(status_text, status_color, stove.worker, stove.worker.character_name)
	else:
		_set_stove_status_row(status_text, status_color)

func _set_stove_status_row(text: String, color: Color, link_target = null, link_text: String = "") -> void:
	if not is_instance_valid(_status_row_instance):
		_show_status_row(text, color, link_target, link_text)
		return

	(_status_row_instance.get_node("ColorRect") as ColorRect).color = color
	var label := _status_row_instance.get_node("HBoxContainer/Label") as Label
	label.text = str(" ", text)
	var font_color := _get_status_row_font_color(color)
	label.add_theme_color_override("font_color", font_color)
	var btn := _status_row_instance.get_node("HBoxContainer/Button") as Button
	_set_status_row_button_color(btn, font_color)
	Util.disconnect_all_pressed(btn)
	if link_target != null:
		btn.text = link_text
		btn.show()
		btn.pressed.connect(func(): manually_select(link_target))
	else:
		btn.hide()

func _get_status_row_font_color(background: Color) -> Color:
	return Color.BLACK if background == Color.YELLOW else Color.WHITE

func _set_status_row_button_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", color)

func _update_gambling_status(room: RoomGambling) -> void:
	var status_text := room.get_round_status_text()
	var status_color := Color.TRANSPARENT
	var link_target = null
	var link_text := ""

	if room.should_warn_no_jackpot() or room.should_warn_start_requirements():
		status_color = Color.YELLOW

	if room.worker:
		link_target = room.worker
		link_text = room.worker.character_name

	_set_stove_status_row(status_text, status_color, link_target, link_text)
	if room.worker:
		room.worker.Tint.add_outline(Color.WHITE, 20, self)

func _rebuild_gambling_ui(room: RoomGambling, force: bool = false) -> void:
	var signature := room.get_ui_state_signature()
	if not force and signature == _gambling_signature:
		return
	_gambling_signature = signature
	gambling_ui.show()
	gambling_host_state.hide()
	gambling_setup_state.hide()
	gambling_active_state.hide()
	gambling_summary_state.hide()

	if room.has_active_round():
		_add_gambling_active_ui(room)
	else:
		_add_gambling_host_ui(room)
		if not room.last_summary.is_empty():
			_add_gambling_summary_ui(room)

func _add_gambling_host_ui(room: RoomGambling) -> void:
	if not room.is_configuring_round():
		gambling_host_state.show()
		return
	gambling_setup_state.show()
	for i in range(RoomGambling.JACKPOT_OPTIONS.size()):
		var jackpot := RoomGambling.JACKPOT_OPTIONS[i]
		var btn := _gambling_jackpot_buttons[i]
		btn.text = "%d$%s" % [jackpot, " *" if jackpot == room.selected_jackpot else ""]
		btn.disabled = not ResourceHandler.has_money(jackpot)
	gambling_selected_jackpot_label.text = "SELECT JACKPOT" if not room.has_selected_jackpot() else "Jackpot %d$" % room.selected_jackpot
	gambling_selected_jackpot_label.add_theme_color_override("font_color", Color.ORANGE if not room.has_selected_jackpot() else Color.WHITE)
	gambling_setup_loop_toggle.set_pressed_no_signal(room.loop_enabled)
	gambling_start_round_button.text = "Start Round" if not room.has_selected_jackpot() else "Start Round (-%d$)" % room.selected_jackpot
	gambling_start_round_button.disabled = not room.has_selected_jackpot() or not ResourceHandler.has_money(room.selected_jackpot)

func _add_gambling_active_ui(room: RoomGambling) -> void:
	gambling_active_state.show()
	if not room.has_required_round_participants():
		gambling_round_status_label.text = "Joined Guests %d/%d" % [room.get_seated_guest_count(), room.max_guest_count]
	else:
		var current_match := mini(room.matches_played + 1, RoomGambling.MATCH_COUNT)
		gambling_round_status_label.text = "Current Match %d/%d" % [current_match, RoomGambling.MATCH_COUNT]
	gambling_round_progress_bar.value = room.get_round_progress() * 100.0
	gambling_watcher_label.text = room.worker.character_name if room.worker != null else "No Watcher Assigned"
	gambling_watcher_label.add_theme_color_override("font_color", Color.WHITE if room.worker != null else Color.ORANGE)
	gambling_round_detail_label.text = "Guests %d/%d, Bank Wins %d" % [room.get_seated_guest_count(), room.max_guest_count, int(room.last_summary.get("bank_wins", 0))]
	gambling_active_loop_toggle.set_pressed_no_signal(room.loop_enabled)

func _add_gambling_summary_ui(room: RoomGambling) -> void:
	gambling_summary_state.show()
	var summary := room.last_summary
	var player_count: int = int(summary.get("player_count", 0))
	if player_count == 0 and int(summary.jackpot) > 0:
		player_count = roundi(float(summary.player_stakes) / float(summary.jackpot))
	var cheating_losses := -int(summary.get("successful_cheat_payouts", 0.0))
	var honest_player_wins := -int(float(summary.player_payouts) - float(summary.get("successful_cheat_payouts", 0.0)))
	_set_gambling_summary_row(_gambling_summary_rows.jackpot, int(summary.jackpot))
	_set_gambling_summary_row(_gambling_summary_rows.fees, int(summary.jackpot), "x %d" % player_count)
	_set_gambling_summary_row(_gambling_summary_rows.player_wins, honest_player_wins, "(%d)" % int(summary.player_wins - summary.successful_cheats))
	_set_gambling_summary_row(_gambling_summary_rows.cheating, cheating_losses, "(%d)" % int(summary.successful_cheats))
	_set_gambling_summary_row(_gambling_summary_rows.returned, int(summary.get("returned_to_house", 0.0)))
	_set_gambling_summary_row(_gambling_summary_rows.net_result, int(summary.revenue), "", true)

func _set_gambling_summary_row(row: HBoxContainer, amount: int, suffix: String = "", emphasize: bool = false) -> void:
	var amount_label := row.get_node("AmountLabel") as Label
	var suffix_label := row.get_node("SuffixLabel") as Label
	amount_label.text = "+%d$" % amount if amount > 0 else "%d$" % amount
	if amount > 0:
		amount_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	elif amount < 0:
		amount_label.add_theme_color_override("font_color", Color(0.82, 0.09, 0.09))
	else:
		amount_label.add_theme_color_override("font_color", Color.WHITE)
	suffix_label.text = suffix
	suffix_label.visible = suffix != ""

func _get_selected_gambling_room() -> RoomGambling:
	return target as RoomGambling if target is RoomGambling and is_instance_valid(target) else null

func _on_gambling_new_round_pressed() -> void:
	var room := _get_selected_gambling_room()
	if room == null:
		return
	room.begin_new_round_setup()
	_rebuild_gambling_ui(room, true)

func _on_gambling_jackpot_selected(jackpot: int) -> void:
	var room := _get_selected_gambling_room()
	if room == null:
		return
	room.selected_jackpot = jackpot
	_rebuild_gambling_ui(room, true)

func _on_gambling_setup_loop_toggled(pressed: bool) -> void:
	var room := _get_selected_gambling_room()
	if room == null:
		return
	room.set_loop_enabled(pressed)
	_rebuild_gambling_ui(room, true)

func _on_gambling_active_loop_toggled(pressed: bool) -> void:
	var room := _get_selected_gambling_room()
	if room == null:
		return
	room.set_loop_enabled(pressed)
	_rebuild_gambling_ui(room, true)

func _on_gambling_start_round_pressed() -> void:
	var room := _get_selected_gambling_room()
	if room == null or not room.has_selected_jackpot():
		return
	room.start_round(room.selected_jackpot)
	_rebuild_gambling_ui(room, true)

func _on_gambling_summary_host_pressed() -> void:
	var room := _get_selected_gambling_room()
	if room == null:
		return
	room.begin_new_round_setup()
	_rebuild_gambling_ui(room, true)

func _show_storage_filter(room: RoomStorage):
	storage_filter_container.visible = true
	Util.delete_all_children_execept_index_0(storage_filter_grid)
	for item_type in Enum.Items.values().filter(func(t): return t != Enum.Items.BROOM and t != Enum.Items.MONEY and t != Enum.Items.CRATE and t != Enum.Items.PICKAXE):
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

	_refresh_storage_items(room)

func _refresh_storage_items(storage: RoomStorageBase, force: bool = false) -> void:
	var signature := _get_storage_items_signature(storage)
	if not force and signature == _storage_items_signature:
		return

	_storage_items_signature = signature
	if is_instance_valid(_storage_items_container):
		_storage_items_container.queue_free()

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	var parent := storage_filter_container.get_parent()
	parent.add_child(container)
	parent.move_child(container, storage_filter_container.get_index() + 1)
	_storage_items_container = container

	var title := status_icon_label_dummy.duplicate() as Label
	title.text = "Stored Items (%d/%d)" % [storage.get_occupied_slot_count(), storage.get_slot_capacity()]
	title.show()
	container.add_child(title)

	var stored_amounts := storage.get_stored_item_amounts()
	if stored_amounts.is_empty():
		var empty_label := status_icon_label_dummy.duplicate() as Label
		empty_label.text = "Empty"
		empty_label.show()
		container.add_child(empty_label)
		return

	var item_types: Array[int] = []
	for item_type in stored_amounts.keys():
		item_types.append(int(item_type))
	item_types.sort()

	for item_type in item_types:
		var row := status_icon_row_dummy.duplicate() as HBoxContainer
		var icon := row.get_child(0) as TextureRect
		var label := row.get_child(1) as Label
		icon.texture = Item.get_info(item_type).Tex
		label.text = "%s x%d" % [Item.get_display_name(item_type), int(stored_amounts[item_type])]
		row.show()
		container.add_child(row)

func _get_storage_items_signature(storage: RoomStorageBase) -> Array:
	var signature: Array = []
	signature.append("%d/%d" % [storage.get_occupied_slot_count(), storage.get_slot_capacity()])
	var stored_amounts := storage.get_stored_item_amounts()
	for item_type in stored_amounts.keys():
		signature.append("%d:%d" % [int(item_type), int(stored_amounts[item_type])])
	signature.sort()
	return signature

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

	call_sheriff_button.show()

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

func _clear_selected_room_outline() -> void:
	if is_instance_valid(target) and target is RoomBase:
		target.set_outline(false, self)

func do_hide():
	_clear_selected_room_outline()
	target = null
	_manual_follow_offset = Vector2.ZERO
	_follow_side = 0

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

	_connection_line.hide()
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

	if not ConflictResponseHandler.can_be_arrested(guest):
		arrest_button.text = "On Horse"
		arrest_button.disabled = true
		return

	arrest_button.disabled = false
	arrest_button.text = "Unmark Arrest" if ConflictResponseHandler.is_marked_for_arrest(guest) else "Mark for Arrest"
	arrest_button.pressed.connect(func():
		if not is_instance_valid(guest):
			return
		if ConflictResponseHandler.is_marked_for_arrest(guest):
			ConflictResponseHandler.unmark_for_arrest(guest)
		else:
			ConflictResponseHandler.mark_for_arrest(guest)
		_bind_guest_arrest_button(guest)
	)

func _bind_worker_fight_response(worker: NPCWorker) -> void:
	if not is_instance_valid(worker):
		worker_fight_response_row.hide()
		return

	Util.disconnect_all_pressed(worker_conflict_button)

	var locked_by_traits: bool = worker.Traits.forces_fight_response() or worker.Traits.refuses_voluntary_fights()
	var is_fight: bool = worker.should_fight_conflicts()
	worker_conflict_label.text = "in conflict I"
	worker_conflict_button.text = "fight" if is_fight else "flee"
	worker_conflict_button.disabled = locked_by_traits
	if locked_by_traits:
		worker_conflict_label.text = "trait makes me"
		return
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

	return

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

	var cost = guest.Traits.get_hire_cost()
	Util.disconnect_all_pressed(hire_guest_button)
	hire_guest_button.disabled = false
	hire_guest_button.text = "Hire for %d$" % cost
	hire_guest_button.pressed.connect(func():
		if not is_instance_valid(guest):
			return
		if not ResourceHandler.has_money(cost):
			var btn_center = hire_guest_button.global_position + hire_guest_button.size / 2
			UiNotifications.create_notification_ui("not enough money", btn_center, null, Color.ORANGE)
			return

		hire_guest_button.disabled = true
		ResourceHandler.change_money(-cost)
		var worker := Global.NPCSpawner.hire_guest_as_worker(guest)
		if is_instance_valid(worker):
			manually_select(worker)
	)

func _process(delta):
	super._process(delta)

	if target == null:
		return

	if not is_instance_valid(target):
		do_hide()
		return

	_update_floating_panel_position()

	var connection_target: Node = null
	if target is RoomBase:
		var room := target as RoomBase
		if is_instance_valid(room.worker):
			connection_target = room.worker
	elif target is NPCWorker:
		var worker := target as NPCWorker
		if worker.current_job != Enum.Jobs.IDLE and is_instance_valid(worker.current_job_room):
			connection_target = worker.current_job_room

	if is_instance_valid(connection_target):
		var npc_pos: Vector2
		var anchor_pos: Vector2
		if target is RoomBase:
			npc_pos = connection_target.global_position - Vector2(0, 12)
			anchor_pos = _room_edge_toward(target as RoomBase, npc_pos)
		else:
			npc_pos = target.global_position - Vector2(0, 12)
			anchor_pos = _room_edge_toward(connection_target as RoomBase, npc_pos)
		_connection_line.global_position = anchor_pos
		_connection_line.target_position = npc_pos
		_connection_line.show()
	else:
		_connection_line.hide()

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

	if target is RoomStove:
		_update_stove_status(target)

	if target is RoomGambling:
		var gambling := target as RoomGambling
		_update_gambling_status(gambling)
		_rebuild_gambling_ui(gambling)
		room_delete_button.text = "Round Active" if not gambling.can_delete() else "Delete Room"
		room_delete_button.disabled = not gambling.can_delete()

	if target is RoomStorageBase and is_instance_valid(_storage_items_container):
		_refresh_storage_items(target)

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
			narrative_label.text = "[color=#888888]" + narrative + "[/color]"
			narrative_label.visible = narrative != ""

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

	_keep_bottom_items_last()

func _update_floating_panel_position() -> void:
	if target == null or not is_instance_valid(target):
		return

	_sync_panel_size()
	var target_rect := _get_target_ui_rect()
	var default_panel_position := _get_default_panel_position(target_rect)

	if drag_button.button_pressed:
		_manual_follow_offset = global_position - default_panel_position
	else:
		global_position = _clamp_panel_position(default_panel_position + _manual_follow_offset)

	var target_ui_position := target_rect.get_center()
	line.global_position = _panel_edge_toward(target_ui_position)
	line.target_position = target_ui_position

func _get_target_ui_rect() -> Rect2:
	if target is RoomBase:
		var room := target as RoomBase
		var room_size_world := Vector2(
			float((room.data.width if room.data != null else 1)) * _ROOM_TILE_SIZE,
			float((room.data.height if room.data != null else 1)) * _ROOM_TILE_SIZE
		)
		var top_left: Vector2 = Util.world_to_ui_position(room.global_position - Vector2(0, room_size_world.y), self, Camera)
		var bottom_right: Vector2 = Util.world_to_ui_position(room.global_position + Vector2(room_size_world.x, 0), self, Camera)
		var rect_position := Vector2(minf(top_left.x, bottom_right.x), minf(top_left.y, bottom_right.y))
		var rect_size := Vector2(absf(bottom_right.x - top_left.x), absf(bottom_right.y - top_left.y))
		return Rect2(rect_position, rect_size)

	var npc_position: Vector2 = Util.world_to_ui_position(target.global_position + _NPC_SELECTION_OFFSET, self, Camera)
	return Rect2(npc_position, Vector2.ZERO)

func _sync_panel_size() -> void:
	var min_size := get_combined_minimum_size()
	size = Vector2(ceilf(min_size.x), ceilf(min_size.y))

func _get_panel_size() -> Vector2:
	return size

func _get_default_panel_position(target_rect: Rect2) -> Vector2:
	var panel_size := _get_panel_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var target_center := target_rect.get_center()
	var can_place_right := target_rect.position.x + target_rect.size.x + _PANEL_TARGET_GAP + panel_size.x <= viewport_size.x - _PANEL_SCREEN_MARGIN
	var can_place_left := target_rect.position.x - _PANEL_TARGET_GAP - panel_size.x >= _PANEL_SCREEN_MARGIN

	if _follow_side == 0:
		_follow_side = -1

	if _follow_side == 1 and not can_place_right and can_place_left:
		_follow_side = -1
	elif _follow_side == -1 and not can_place_left and can_place_right:
		_follow_side = 1
	elif not can_place_right and not can_place_left:
		var left_space := target_rect.position.x - _PANEL_SCREEN_MARGIN
		var right_space := viewport_size.x - _PANEL_SCREEN_MARGIN - (target_rect.position.x + target_rect.size.x)
		_follow_side = -1 if left_space >= right_space else 1

	var x := target_rect.position.x + target_rect.size.x + _PANEL_TARGET_GAP if _follow_side == 1 else target_rect.position.x - panel_size.x - _PANEL_TARGET_GAP
	return Vector2(x, target_center.y - panel_size.y * 0.5)

func _clamp_panel_position(panel_position: Vector2) -> Vector2:
	var panel_size := _get_panel_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var max_x := maxf(_PANEL_SCREEN_MARGIN, viewport_size.x - panel_size.x - _PANEL_SCREEN_MARGIN)
	var max_y := maxf(_PANEL_SCREEN_MARGIN, viewport_size.y - panel_size.y - _PANEL_SCREEN_MARGIN)
	return Vector2(
		clampf(panel_position.x, _PANEL_SCREEN_MARGIN, max_x),
		clampf(panel_position.y, _PANEL_SCREEN_MARGIN, max_y)
	)

func _panel_edge_toward(toward: Vector2) -> Vector2:
	var panel_size := _get_panel_size()
	var rect := Rect2(global_position, panel_size)
	return Vector2(
		clampf(toward.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(toward.y, rect.position.y, rect.position.y + rect.size.y)
	)

func _room_edge_toward(room: RoomBase, toward: Vector2) -> Vector2:
	const TILE := 48
	var w: int = (room.data.width if room.data else 1) * TILE
	var h: int = (room.data.height if room.data else 1) * TILE
	# Room origin is bottom-left; y extends upward (negative y direction)
	var rect := Rect2(room.global_position.x, room.global_position.y - h, w, h)
	var cx := clampf(toward.x, rect.position.x, rect.position.x + rect.size.x)
	var cy := clampf(toward.y, rect.position.y, rect.position.y + rect.size.y)
	return Vector2(cx, cy)
