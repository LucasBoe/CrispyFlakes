extends Control

@onready var _item_name:    Label        = $Margin/VBox/ItemName
@onready var _item_cost:    Label        = $Margin/VBox/ItemCost
@onready var _room_section:  VBoxContainer    = $Margin/VBox/RoomSection
@onready var _room_preview:  TextureRect      = $Margin/VBox/RoomSection/RoomPreview
@onready var _room_name:     Label            = $Margin/VBox/RoomSection/RoomName
@onready var _room_desc:     Label            = $Margin/VBox/RoomSection/RoomDesc
@onready var _room_recipe = $Margin/VBox/RoomSection/RoomRecipeDisplay
@onready var _buy_button = $Margin/VBox/BuyButton
@onready var _buy_content: Control      = $Margin/VBox/BuyButton/MarginContainer
@onready var _buy_label:    Label        = $Margin/VBox/BuyButton/MarginContainer/MarginContainer/Label

var _current_item: ProgressionItem = null

func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	ProgressionHandler.item_unlocked.connect(func(_i): _refresh_buy_button())
	ProgressionHandler.points_changed.connect(func(_p): _refresh_buy_button())
	hide()

func on_item_selected(item: ProgressionItem) -> void:
	_current_item = item
	if item == null:
		hide()
		return

	show()
	_item_name.text = item.display_name
	_item_cost.text = "%d pts" % item.cost

	if item.unlocks_room != null:
		_room_section.show()
		_room_preview.texture = item.unlocks_room.room_preview
		_room_name.text = item.unlocks_room.room_name
		_room_desc.text = item.unlocks_room.room_desc
		_room_recipe.show_for_data(item.unlocks_room)
	else:
		_room_section.hide()

	_refresh_buy_button()

func _refresh_buy_button() -> void:
	if _current_item == null:
		return
	var owned := ProgressionHandler.is_item_unlocked(_current_item)
	var dep_met := _current_item.depends_on == null or ProgressionHandler.is_item_unlocked(_current_item.depends_on)
	var can_afford := ProgressionHandler.get_points() >= _current_item.cost
	var disabled := owned or not dep_met or not can_afford
	var label_text: String
	if owned:
		label_text = "Owned"
	elif not dep_met:
		label_text = "Locked"
	else:
		label_text = "Buy (%d pts)" % _current_item.cost

	_buy_button.disabled = disabled
	_buy_content.visible = not disabled
	_buy_button.text = label_text if disabled else ""
	if not disabled:
		_buy_label.text = label_text
	_buy_button.fit_to_content()

func _on_buy_pressed() -> void:
	if _current_item == null:
		return
	ProgressionHandler.try_unlock(_current_item)
