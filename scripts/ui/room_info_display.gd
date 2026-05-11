extends VBoxContainer
class_name RoomInfoDisplay

const DONE_MARKER_DONE := preload("res://assets/sprites/ui/2x/tree_done_marker_done.png")
const DONE_MARKER_NOT_DONE := preload("res://assets/sprites/ui/2x/tree_done_marker_not_done.png")

@onready var _name_label: Label = $NameLabel
@onready var _desc_label: RichTextLabel = $HBoxContainer/VBoxContainer/DescLabel
@onready var _price_label: Label = $HBoxContainer/VBoxContainer/PriceLabel
@onready var _preview: TextureRect = $HBoxContainer/MarginContainer/MarginContainer/PreviewTextureRect
@onready var _marker: TextureRect = $HBoxContainer/MarginContainer/MarginContainer/PreviewTextureRect/Marker
@onready var _recipe: HBoxContainer = $HBoxContainer/VBoxContainer/Recipe
@onready var _recipe_consumed: TextureRect = $HBoxContainer/VBoxContainer/Recipe/ConsumedIcon
@onready var _recipe_arrow: Label = $HBoxContainer/VBoxContainer/Recipe/ArrowLabel
@onready var _recipe_produced: TextureRect = $HBoxContainer/VBoxContainer/Recipe/ProducedIcon
@onready var _limit_row: HBoxContainer = $HBoxContainer/VBoxContainer/PlacementLimit
@onready var _limit_icon: TextureRect = $HBoxContainer/VBoxContainer/PlacementLimit/Icon
@onready var _limit_label: Label = $HBoxContainer/VBoxContainer/PlacementLimit/LimitLabel

func show_for(data: BuildableData, show_marker: bool = false, is_built: bool = false) -> void:
	_name_label.text = data.room_name
	_desc_label.text = data.room_desc
	_price_label.text = str(data.construction_price, "$")
	_preview.texture = data.get_display_icon()
	_marker.visible = show_marker
	if show_marker:
		_marker.texture = DONE_MARKER_DONE if is_built else DONE_MARKER_NOT_DONE
	_show_recipe(data)
	_show_placement_limit(data)

func set_desc(text: String) -> void:
	_desc_label.text = text

func _show_recipe(data: BuildableData) -> void:
	if not data is RoomData or not (data.has_consumed_item or data.produces_item or data.produces_money):
		_recipe.hide()
		return
	_recipe_consumed.visible = data.has_consumed_item
	_recipe_arrow.visible = data.has_consumed_item and (data.produces_item or data.produces_money)
	_recipe_produced.visible = data.produces_item or data.produces_money
	if data.has_consumed_item:
		_recipe_consumed.texture = Item.get_info(data.consumed_item_type).Tex
	if data.produces_item:
		_recipe_produced.texture = Item.get_info(data.produced_item_type).Tex
	elif data.produces_money:
		var coin_tex := AtlasTexture.new()
		coin_tex.atlas = preload("res://assets/sprites/coins-sprite-sheet.png")
		coin_tex.region = Rect2(0, 0, 8, 8)
		_recipe_produced.texture = coin_tex
	_recipe.show()

func _show_placement_limit(data: BuildableData) -> void:
	if not data is RoomData:
		_limit_row.hide()
		return
	var limit: Enum.PlacementLimit = data.placement_limit
	var tint := Color(0.6, 0.6, 0.6) if limit == Enum.PlacementLimit.ABOVE_OR_BELOW else Color.WHITE
	_limit_icon.texture = Enum.placement_limit_to_icon(limit)
	_limit_icon.modulate = tint
	_limit_label.text = Enum.PlacementLimit.keys()[limit].capitalize().replace("_", " ")
	_limit_label.modulate = tint
	_limit_row.show()
