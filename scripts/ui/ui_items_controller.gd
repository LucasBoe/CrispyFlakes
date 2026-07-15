extends Node

class_name UIItemsController

const REFRESH_INTERVAL := 0.25
const DRINK_FALLBACK_TEXTURE := preload("res://assets/sprites/item_drink_water.png")

@onready var _ui_root: Control = get_parent() as Control
@onready var _row_container: HBoxContainer = $"../MarginContainer/HBoxContainer"
@onready var _template_row: VBoxContainer = $"../MarginContainer/HBoxContainer/Item_VBoxContainer"
var _refresh_time_left := 0.0
var _last_signature: Array = []

func _ready() -> void:
	_reset_display()
	_refresh(true)
	_refresh_time_left = REFRESH_INTERVAL

func _process(delta: float) -> void:
	_refresh_time_left -= delta
	if _refresh_time_left > 0.0:
		return

	_refresh_time_left = REFRESH_INTERVAL
	_refresh()

func _refresh(force: bool = false) -> void:
	var counts := _collect_item_counts()
	var signature := _build_signature(counts)
	if not force and signature == _last_signature:
		return

	_last_signature = signature
	_apply_counts(counts)

func _collect_item_counts() -> Dictionary:
	var counts := LooseItemHandler.get_loose_item_amounts()
	var stored_amounts := RoomStorageBase.get_global_stored_item_amounts()
	for item_type in stored_amounts.keys():
		counts[int(item_type)] = int(counts.get(int(item_type), 0)) + int(stored_amounts[item_type])

	for item_type in counts.keys().duplicate():
		if Item.is_shadow_item(int(item_type)):
			counts.erase(item_type)
	return counts

func _build_signature(counts: Dictionary) -> Array:
	var signature: Array = []
	for item_type in counts.keys():
		signature.append("%d:%d" % [int(item_type), int(counts[item_type])])
	signature.sort()
	return signature

func _apply_counts(counts: Dictionary) -> void:
	_clear_duplicate_rows()

	var ordered_types: Array[int] = []
	for item_type in counts.keys():
		ordered_types.append(int(item_type))
	ordered_types.sort()

	if ordered_types.is_empty():
		_template_row.hide()
		_ui_root.hide()
		return

	_ui_root.show()

	for i in ordered_types.size():
		var row := _template_row if i == 0 else _template_row.duplicate() as VBoxContainer
		if i > 0:
			_row_container.add_child(row)

		_apply_row(
			row,
			ordered_types[i],
			int(counts[ordered_types[i]])
		)

func _clear_duplicate_rows() -> void:
	for i in range(_row_container.get_child_count() - 1, -1, -1):
		var child := _row_container.get_child(i)
		if child == _template_row:
			continue
		_row_container.remove_child(child)
		child.queue_free()

func _apply_row(row: VBoxContainer, item_type: int, amount: int) -> void:
	var amount_label := row.get_node("Amount_Label") as Label
	var icon_rect := row.get_node("Icon_TextureRect") as TextureRect
	var texture := _get_icon_texture(item_type, amount)
	amount_label.text = str(amount)
	icon_rect.texture = texture
	row.tooltip_text = "%s x%d" % [_get_item_label(item_type), amount]
	row.show()

func _reset_display() -> void:
	_clear_duplicate_rows()
	_template_row.hide()
	_ui_root.hide()

func _get_icon_texture(item_type: int, amount: int) -> Texture:
	if item_type == Enum.Items.MONEY:
		return Item.get_money_texture(float(amount))

	var info := Item.get_info(item_type)
	if info.Tex != null:
		return info.Tex

	if item_type == Enum.Items.DRINK:
		return DRINK_FALLBACK_TEXTURE

	return null

func _get_item_label(item_type: int) -> String:
	if item_type >= 0 and item_type < Enum.Items.keys().size():
		return Item.get_display_name(item_type)
	return "Item"
