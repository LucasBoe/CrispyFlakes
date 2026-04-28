extends HBoxContainer
class_name RoomRecipeDisplay

@onready var _consumed_icon: TextureRect = $ConsumedIcon
@onready var _arrow: Label = $ArrowLabel
@onready var _produced_icon: TextureRect = $ProducedIcon


func show_for_data(data: RoomData) -> void:
	if data == null or not (data.has_consumed_item or data.produces_item or data.produces_money):
		hide()
		return

	_consumed_icon.visible = data.has_consumed_item
	_arrow.visible = data.has_consumed_item and (data.produces_item or data.produces_money)
	_produced_icon.visible = data.produces_item or data.produces_money

	if data.has_consumed_item:
		_consumed_icon.texture = Item.get_info(data.consumed_item_type).Tex
	if data.produces_item:
		_produced_icon.texture = Item.get_info(data.produced_item_type).Tex
	elif data.produces_money:
		var coin_tex := AtlasTexture.new()
		coin_tex.atlas = preload("res://assets/sprites/coins-sprite-sheet.png")
		coin_tex.region = Rect2(0, 0, 8, 8)
		_produced_icon.texture = coin_tex

	show()
