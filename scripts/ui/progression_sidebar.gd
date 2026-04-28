extends Control

@onready var _item_icon:    TextureRect  = $Margin/VBox/ItemIcon
@onready var _item_name:    Label        = $Margin/VBox/ItemName
@onready var _item_cost:    Label        = $Margin/VBox/ItemCost
@onready var _room_section: VBoxContainer = $Margin/VBox/RoomSection
@onready var _room_preview: TextureRect  = $Margin/VBox/RoomSection/RoomPreview
@onready var _room_name:    Label        = $Margin/VBox/RoomSection/RoomName
@onready var _room_desc:    Label        = $Margin/VBox/RoomSection/RoomDesc
@onready var _buy_button:   Button       = $Margin/VBox/BuyButton

var _current_item: ProgressionItem = null

func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	ProgressionHandler.item_unlocked.connect(func(_i): _refresh_buy_button())
	ProgressionHandler.points_changed.connect(func(_p): _refresh_buy_button())

func on_item_selected(item: ProgressionItem) -> void:
	_current_item = item
	if item == null:
		hide()
		return

	show()
	_item_icon.texture = item.sprite
	_item_name.text = item.display_name
	_item_cost.text = "%d pts" % item.cost

	if item.unlocks_room != null:
		_room_section.show()
		_room_preview.texture = item.unlocks_room.room_preview
		_room_name.text = item.unlocks_room.room_name
		_room_desc.text = item.unlocks_room.room_desc
	else:
		_room_section.hide()

	_refresh_buy_button()

func _refresh_buy_button() -> void:
	if _current_item == null:
		return
	var owned := ProgressionHandler.is_item_unlocked(_current_item)
	var can_afford := ProgressionHandler.get_points() >= _current_item.cost
	_buy_button.disabled = owned or not can_afford
	_buy_button.text = "Owned" if owned else "Buy (%d pts)" % _current_item.cost

func _on_buy_pressed() -> void:
	if _current_item == null:
		return
	ProgressionHandler.try_unlock(_current_item)
