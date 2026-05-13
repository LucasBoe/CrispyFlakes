extends MenuUITab
class_name BuildMenuUITab

const LOCK_ICON = preload("res://assets/sprites/ui/icon_locked.png")

@onready var tab_cointainer : TabBar = $MarginContainer/GridContainer/TabBar
@onready var room_tier_dummy : Control = $MarginContainer/GridContainer/RoomTierDummy

@onready var hover_info_room_box_root = $UIRoomHoverInfo
@onready var _hover_info: RoomInfoDisplay = %RoomBuildHoverInfo

var groups = {}

var last_hover = null
var data_to_button : Dictionary = {}
var _new_unlock_data: Dictionary = {}

func _ready():
	tab_cointainer.tab_changed.connect(_on_tab_changed)
	GlobalEventHandler.on_room_created_signal.connect(_on_buildables_changed)
	GlobalEventHandler.on_room_deleted_signal.connect(_on_buildables_changed)
	GlobalEventHandler.on_infrastructure_changed_signal.connect(_on_buildables_changed)
	ProgressionHandler.item_unlocked.connect(_on_progression_item_unlocked)

	for t in Enum.RoomType.values():
		groups[t] = room_group.new(t)
	
	create_button(groups, Building.room_data_empty)
	create_button(groups, Building.room_data_digging, RoomDigging.custom_placement_check)
	create_button(groups, Building.room_data_table)
	create_button(groups, Building.room_data_bar)
	create_button(groups, Building.room_data_stairs)
	create_button(groups, Building.room_data_broom_closet)
	create_button(groups, Building.room_data_storage)
	create_button(groups, Building.room_data_outhouse, RoomOuthouse.custom_placement_check)
	create_button(groups, Building.room_data_brewery)
	create_button(groups, Building.room_data_bar_beer)
	create_button(groups, Building.room_data_gambling)
	create_button(groups, Building.room_data_entertainment)
	create_button(groups, Building.room_data_saloon)
	create_button(groups, Building.room_data_bed)
	create_button(groups, Building.room_data_horse_post, RoomHorsePost.custom_placement_check)
	create_button(groups, Building.room_data_safe)
	create_button(groups, Building.room_data_bouncer, RoomBouncer.custom_placement_check)
	create_button(groups, Building.room_data_prison)
	create_button(groups, Building.room_data_trading_office)
	create_button(groups, Building.room_data_destillery)
	create_button(groups, Building.room_data_aging_cellar)
	create_button(groups, Building.room_data_bar_whiskey)
	create_button(groups, Building.room_data_water_tower, RoomWaterTower.custom_placement_check)
	create_button(groups, Building.infrastructure_data_water_pipe, null, PlacementHandler.start_building_infrastructure)
	create_button(groups, Building.room_data_toilet)
	create_button(groups, Building.room_data_bath)
	create_button(groups, Building.room_data_infirmary)
	create_button(groups, Building.room_data_sick_ward)
	_on_tab_changed(0)
	room_tier_dummy.hide()
	hover_info_room_box_root.hide()

	_refresh_button_availability()

func create_button(room_groups : Dictionary, data : BuildableData, custom_placement_check = null, build_action: Callable = PlacementHandler.start_building):

	var group = room_groups[data.room_type]
	var tier = 0
	while group.tiers.size() <= tier:
		group.create_new_tier_dummy(room_tier_dummy)

	var button_dummy = group.button_dummies[tier]

	var instance : Button = button_dummy.duplicate()
	button_dummy.get_parent().add_child(instance)
	instance.visible = true
	instance.icon = data.room_icon if data.room_icon else data.room_preview
	var _initial_count: int = _count_buildable(data)
	instance.text = "" if _initial_count == 0 else str(_initial_count)
	instance.button_down.connect(_on_build_button_pressed.bind(data, custom_placement_check, build_action))
	instance.mouse_entered.connect(_on_hover_enter.bind(instance, data))
	instance.mouse_exited.connect(_on_hover_exit.bind(instance, data))
	instance.show()
	instance.add_child(_create_locked_overlay())

	var placement_icon := instance.get_node_or_null("PlacementLimitIcon") as TextureRect
	if placement_icon and data is RoomData:
		var limit: Enum.PlacementLimit = data.placement_limit
		if limit == Enum.PlacementLimit.ABOVE_OR_BELOW:
			placement_icon.hide()
		else:
			placement_icon.texture = Enum.placement_limit_to_icon(limit)
			placement_icon.show()

	if not group.button_instances.has(tier):
		group.button_instances[tier] = []

	group.button_instances[tier].append(instance)
	data_to_button[data] = instance

	return instance

func _on_buildables_changed(_changed = null):
	for data in data_to_button:
		var count: int = _count_buildable(data)
		data_to_button[data].text = "" if count == 0 else str(count)
	_refresh_button_availability()
	if last_hover != null:
		_refresh_desc(last_hover)

func _on_progression_item_unlocked(item: ProgressionItem) -> void:
	if item == null:
		return

	if not item.get_required_items().is_empty():
		for room in item.get_unlocked_rooms():
			_new_unlock_data[room] = true

	_on_buildables_changed(item)

func _refresh_desc(data):
	var count: int = _count_buildable(data)
	var description: String = data.room_desc + "\nhas: " + str(count)
	if not _is_data_unlocked(data):
		var unlock_text := _get_unlock_text(data)
		if unlock_text != "":
			description += "\n[color=#ff8f5a]%s[/color]" % unlock_text
	_hover_info.set_desc(description)

func _count_buildable(data) -> int:
	if data is InfrastructureData:
		return Building.infrastructure.count_cells_by_data(data)
	return Building.count_rooms_by_data(data)

func _on_hover_enter(button : Button, data):
	if _new_unlock_data.has(data):
		_new_unlock_data.erase(data)
		_refresh_button_availability()
	_hover_info.show_for(data)
	_refresh_desc(data)
	last_hover = data
	hover_info_room_box_root.show()
	return

func _on_hover_exit(button : Button, data):
	if last_hover == data:
		last_hover = null
		hover_info_room_box_root.hide()
	return

func _on_tab_changed(tab):

	SoundPlayer.play_ui_click_down()

	var group = groups[tab]

	for g in groups.values():
		for tier_node in g.tiers:
			tier_node.hide()
		for x in g.button_instances.values():
			for button in x:
				button.hide()

	for tier in group.button_instances.keys():
		for button in group.button_instances[tier]:
			button.show()
		if group.button_instances[tier].any(func(b): return b.visible):
			group.tiers[tier].show()

func _on_build_button_pressed(data, custom_placement_check, build_action: Callable) -> void:
	if not _is_data_unlocked(data):
		return
	SoundPlayer.play_ui_click_down()
	build_action.call(data, custom_placement_check)

func _refresh_button_availability() -> void:
	for data in data_to_button:
		var button := data_to_button[data] as Button
		var unlocked := _is_data_unlocked(data)
		button.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.5, 1.0)
		var overlay := button.get_node_or_null("LockedOverlay") as Control
		if overlay != null:
			overlay.visible = not unlocked
		var new_unlock_overlay := button.get_node_or_null("NewUnlockGlowOverlay") as Control
		if new_unlock_overlay != null:
			new_unlock_overlay.visible = unlocked and _new_unlock_data.has(data)

func _is_data_unlocked(data) -> bool:
	if data is InfrastructureData:
		return ProgressionHandler.is_infrastructure_build_unlocked(data)
	if data is RoomData:
		return ProgressionHandler.is_room_build_unlocked(data)
	return true

func _get_unlock_text(data) -> String:
	var item: ProgressionItem = null
	if data is InfrastructureData:
		item = ProgressionHandler.get_item_for_infrastructure(data)
	elif data is RoomData:
		item = ProgressionHandler.get_item_for_room(data)

	if item != null:
		var missing := ProgressionHandler.get_missing_requirements(item)
		if not missing.is_empty():
			var names: Array[String] = []
			for requirement in missing:
				names.append(requirement.display_name)
			return "Complete %s to unlock this group" % ", ".join(names)
		return "This becomes available through the progression tree"
	return ""

func _create_locked_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "LockedOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.add_child(shade)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = LOCK_ICON
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	center.add_child(icon)

	overlay.hide()
	return overlay

class room_group:
	var room_type : Enum.RoomType
	var group_name : String
	var tiers = []
	var overlays = []
	var button_dummies = []
	var button_instances = {}

	func _init(type : Enum.RoomType):
		room_type = type
		group_name = Enum.RoomType.keys()[type]

	func create_new_tier_dummy(tier_dummy : Control):

		var tier_level = tiers.size()
		var clone = tier_dummy.duplicate()
		tier_dummy.get_parent().add_child(clone)

		tiers.append(clone)
		var overlay = clone.get_child(1)
		overlays.append(overlay)
		overlay.hide()
		var button_dummy = clone.get_child(0).get_child(0).get_child(0)
		button_dummies.append(button_dummy)
		button_dummy.hide()
		return self
