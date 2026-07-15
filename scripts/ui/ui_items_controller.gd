extends Node

class_name UIItemsController

const REFRESH_INTERVAL := 0.25
const BLOCKED_HIGHLIGHT_DURATION := 10.0
const BLOCKED_LABEL_COLOR := Color(1.0, 0.9, 0.25, 1.0)
const BLOCKED_BLINK_DIM_ALPHA := 0.3
const BLOCKED_BLINK_SPEED := 7.0
const DRINK_FALLBACK_TEXTURE := preload("res://assets/sprites/item_drink_water.png")

@onready var _ui_root: Control = get_parent() as Control
@onready var _row_container: HBoxContainer = $"../MarginContainer/HBoxContainer"
@onready var _template_row: VBoxContainer = $"../MarginContainer/HBoxContainer/Item_VBoxContainer"
@onready var _template_amount_label: Label = $"../MarginContainer/HBoxContainer/Item_VBoxContainer/Amount_Label"

var _refresh_time_left := 0.0
var _last_signature: Array = []
var _rows_by_item_type: Dictionary = {}
var _default_label_modulate := Color.WHITE
var _blocked_item_type := -1
var _blocked_item_time_left := 0.0
var _blocked_item_blink_time := 0.0

func _ready() -> void:
	_default_label_modulate = _template_amount_label.modulate
	if not GlobalEventHandler.on_item_needed_signal.is_connected(_on_item_needed):
		GlobalEventHandler.on_item_needed_signal.connect(_on_item_needed)

	_reset_display()
	_refresh(true)
	_refresh_time_left = REFRESH_INTERVAL

func _process(delta: float) -> void:
	_refresh_time_left -= delta
	if _refresh_time_left <= 0.0:
		_refresh_time_left = REFRESH_INTERVAL
		_refresh()

	if _blocked_item_time_left > 0.0:
		_blocked_item_time_left = maxf(0.0, _blocked_item_time_left - delta)
		_blocked_item_blink_time += delta
		if _blocked_item_time_left <= 0.0:
			_blocked_item_type = -1
			_blocked_item_blink_time = 0.0
			_refresh(true)

	_update_row_highlight_state()

func _on_item_needed(item_type: int) -> void:
	if _blocked_item_time_left > 0.0:
		return
	if Item.is_shadow_item(item_type):
		return

	_blocked_item_type = item_type
	_blocked_item_time_left = BLOCKED_HIGHLIGHT_DURATION
	_blocked_item_blink_time = 0.0
	_refresh(true)
	_update_row_highlight_state()

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
	if _blocked_item_type >= 0 and not signature.has("%d:0" % _blocked_item_type):
		signature.append("blocked:%d" % _blocked_item_type)
	signature.sort()
	return signature

func _apply_counts(counts: Dictionary) -> void:
	_clear_duplicate_rows()
	_rows_by_item_type.clear()

	var ordered_types: Array[int] = []
	for item_type in counts.keys():
		ordered_types.append(int(item_type))
	if _blocked_item_type >= 0 and _blocked_item_type not in ordered_types:
		ordered_types.append(_blocked_item_type)
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

		var item_type := ordered_types[i]
		var amount := int(counts.get(item_type, 0))
		_rows_by_item_type[item_type] = row
		_apply_row(row, item_type, amount)

	_update_row_highlight_state()

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
	amount_label.modulate = _default_label_modulate
	icon_rect.texture = texture
	icon_rect.modulate = Color.WHITE
	row.modulate = Color.WHITE
	row.tooltip_text = "%s x%d" % [_get_item_label(item_type), amount]
	row.show()

func _update_row_highlight_state() -> void:
	for item_type in _rows_by_item_type.keys():
		var row := _rows_by_item_type[item_type] as VBoxContainer
		if not is_instance_valid(row):
			continue

		var amount_label := row.get_node("Amount_Label") as Label
		var icon_rect := row.get_node("Icon_TextureRect") as TextureRect
		if int(item_type) == _blocked_item_type and _blocked_item_time_left > 0.0:
			var blink_strength := 0.5 + 0.5 * sin(_blocked_item_blink_time * TAU * BLOCKED_BLINK_SPEED)
			var alpha := lerpf(BLOCKED_BLINK_DIM_ALPHA, 1.0, blink_strength)
			icon_rect.modulate = Color(1.0, 1.0, 1.0, alpha)
			amount_label.modulate = BLOCKED_LABEL_COLOR
		else:
			icon_rect.modulate = Color.WHITE
			amount_label.modulate = _default_label_modulate

func _reset_display() -> void:
	_clear_duplicate_rows()
	_rows_by_item_type.clear()
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
