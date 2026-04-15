extends MenuUITab
class_name BuildMenuUITab

@onready var tab_cointainer : TabBar = $MarginContainer/GridContainer/TabBar
@onready var room_tier_dummy : Control = $MarginContainer/GridContainer/RoomTierDummy

@onready var hover_info_room_box_root = $UIRoomHoverInfo
@onready var hover_info_room_name_label : Label = %RoomBuildHoverInfoNameLabel
@onready var hover_info_room_desc_label : RichTextLabel = %RoomBuildHoverInfoDescLabel
@onready var hover_info_room_price_label : Label = %RoomBuildHoverInfoPriceLabel
@onready var hover_info_room_preview_texture_rect : TextureRect = %RoomBuildHoverInfoRoomPreviewTextureRect
@onready var hover_info_room_consumed_texture_rect : TextureRect = %RoomBuildHoverInfoConsumedTextureRect
@onready var hover_info_room_arrow_label : Label = %RoomBuildHoverInfoArrowLabel
@onready var hover_info_room_item_texture_rect : TextureRect = %RoomBuildHoverInfoItemTextureRect

const _COIN_ATLAS = preload("res://assets/sprites/coins-sprite-sheet.png")

var groups = {}

var all_tiers = []
var button_dummies = []

var storage_button;
var brewery_button;

var last_hover = null

func _ready():
	tab_cointainer.tab_changed.connect(_on_tab_changed)

	var group = room_group.new(groups)

	create_button(group, Building.room_data_table)
	create_button(group, Building.room_data_bed)
	create_button(group, Building.room_data_stairs, RoomStairs.custom_placement_check)
	create_button(group, Building.room_data_well)
	create_button(group, Building.room_data_water_tower, RoomWaterTower.custom_placement_check)
	create_button(group, Building.room_data_bar)
	create_button(group, Building.room_data_entertainment)
	brewery_button = create_button(group, Building.room_data_brewery)
	storage_button = create_button(group, Building.room_data_storage)
	create_button(group, Building.room_data_outhouse, RoomOuthouse.custom_placement_check)
	create_button(group, Building.room_data_horse_post, RoomHorsePost.custom_placement_check)
	create_button(group, Building.room_data_bath)
	create_button(group, Building.room_data_broom_closet)
	create_button(group, Building.room_data_bouncer, RoomBouncer.custom_placement_check)
	create_button(group, Building.room_data_destillery)
	create_button(group, Building.room_data_aging_cellar)
	create_button(group, Building.room_data_prison)
	create_button(group, Building.room_data_safe)
	_on_tab_changed(0)
	room_tier_dummy.hide()
	TierHandler.tier_unlocked_signal.connect(_on_tier_unlocked)
	hover_info_room_box_root.hide()

func create_button(group : room_group, data : RoomData, custom_placement_check = null):

	var tier = data.tier
	while group.tiers.size() <= tier:
		group.create_new_tier_dummy(room_tier_dummy)

	var button_dummy = group.button_dummies[tier]

	var instance : Button = button_dummy.duplicate()
	button_dummy.get_parent().add_child(instance)
	instance.visible = true
	instance.icon = data.room_icon
	instance.text = str(Building.count_rooms_by_data(data))
	instance.button_down.connect(PlacementHandler.start_building.bind(data, custom_placement_check))
	instance.button_down.connect(SoundPlayer.mouse_click_down.play)
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
	hover_info_room_price_label.text = str(data.construction_price, "$")
	hover_info_room_preview_texture_rect.texture = data.room_preview

	var recipe_row = hover_info_room_item_texture_rect.get_parent()
	recipe_row.visible = data.produces_item or data.has_consumed_item or data.produces_money
	hover_info_room_consumed_texture_rect.visible = data.has_consumed_item
	hover_info_room_arrow_label.visible = data.has_consumed_item and (data.produces_item or data.produces_money)
	if data.has_consumed_item:
		hover_info_room_consumed_texture_rect.texture = Item.get_info(data.consumed_item_type).Tex
	hover_info_room_item_texture_rect.visible = data.produces_item or data.produces_money
	if data.produces_item:
		hover_info_room_item_texture_rect.texture = Item.get_info(data.produced_item_type).Tex
	elif data.produces_money:
		var coin_tex = AtlasTexture.new()
		coin_tex.atlas = _COIN_ATLAS
		coin_tex.region = Rect2(0, 0, 8, 8)
		hover_info_room_item_texture_rect.texture = coin_tex

	last_hover = data
	hover_info_room_box_root.show()
	return

func _on_hover_exit(button : Button, data : RoomData):
	if last_hover == data:
		last_hover = null
		hover_info_room_box_root.hide()
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

func _on_tier_unlocked(tier):
	for g in groups.values():
		for i in g.overlays.size():
			g.overlays[i].visible = i > TierHandler.current_tier

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
