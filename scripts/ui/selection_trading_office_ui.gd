extends VBoxContainer
class_name UISelectionTradingOffice

const BASE_THEME = preload("res://assets/sprites/ui/base_theme.tres")
const HEADER_FONT = preload("res://assets/fonts/modern_dos/ModernDOS8x8.ttf")

var _room = null
var _draft_amounts: Dictionary = {}
var _row_nodes: Dictionary = {}
var _is_order_editor_open := false

var _section_label: Label
var _new_order_button: Button
var _editor_container: VBoxContainer
var _rows_container: VBoxContainer
var _order_now_button: Button
var _progress_label: Label
var _progress_bar: ProgressBar

func _ready() -> void:
	theme = BASE_THEME
	add_theme_constant_override("separation", 4)
	_build_ui()
	hide()

func bind_room(room) -> void:
	if _room != room:
		_room = room
		_reset_draft_amounts()
		_is_order_editor_open = false

	if _room == null:
		clear_room()
		return

	show()
	_refresh()

func clear_room() -> void:
	_room = null
	_is_order_editor_open = false
	hide()
	_refresh()

func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh()

func _build_ui() -> void:
	_section_label = Label.new()
	_section_label.theme = BASE_THEME
	_section_label.text = "Trade Orders"
	_section_label.add_theme_font_override("font", HEADER_FONT)
	_section_label.add_theme_font_size_override("font_size", 16)
	add_child(_section_label)

	_new_order_button = Button.new()
	_new_order_button.theme = BASE_THEME
	_new_order_button.text = "New Order"
	_new_order_button.pressed.connect(_on_new_order_pressed)
	add_child(_new_order_button)

	_editor_container = VBoxContainer.new()
	_editor_container.add_theme_constant_override("separation", 3)
	add_child(_editor_container)

	_rows_container = VBoxContainer.new()
	_rows_container.add_theme_constant_override("separation", 2)
	_editor_container.add_child(_rows_container)

	for item_type in Item.get_trade_orderable_items():
		_create_item_row(item_type)

	_order_now_button = Button.new()
	_order_now_button.theme = BASE_THEME
	_order_now_button.text = "Order Now"
	_order_now_button.pressed.connect(_on_order_now_pressed)
	_editor_container.add_child(_order_now_button)

	_progress_label = Label.new()
	_progress_label.theme = BASE_THEME
	add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.theme = BASE_THEME
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.show_percentage = false
	add_child(_progress_bar)

func _create_item_row(item_type: int) -> void:
	var info := Item.get_info(item_type)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_rows_container.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.texture = info.Tex
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)

	var name_label := Label.new()
	name_label.theme = BASE_THEME
	name_label.text = info.Name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var price_label := Label.new()
	price_label.theme = BASE_THEME
	price_label.text = "%d$" % info.TradePrice
	row.add_child(price_label)

	var minus_button := Button.new()
	minus_button.theme = BASE_THEME
	minus_button.text = "-"
	minus_button.pressed.connect(_adjust_amount.bind(item_type, -1))
	row.add_child(minus_button)

	var amount_label := Label.new()
	amount_label.theme = BASE_THEME
	amount_label.custom_minimum_size = Vector2(24, 0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(amount_label)

	var plus_button := Button.new()
	plus_button.theme = BASE_THEME
	plus_button.text = "+"
	plus_button.pressed.connect(_adjust_amount.bind(item_type, 1))
	row.add_child(plus_button)

	_row_nodes[item_type] = {
		"minus": minus_button,
		"amount": amount_label,
	}

func _refresh() -> void:
	if _room == null or not is_instance_valid(_room):
		_section_label.visible = false
		_new_order_button.visible = false
		_editor_container.visible = false
		_progress_label.visible = false
		_progress_bar.visible = false
		return

	_section_label.visible = true
	_new_order_button.visible = true

	var has_worker: bool = _room.has_assigned_worker()
	var has_active_delivery: bool = _room.has_active_delivery()
	if not has_worker:
		_is_order_editor_open = false
	_new_order_button.disabled = has_active_delivery or not has_worker
	_editor_container.visible = _is_order_editor_open and not has_active_delivery and has_worker
	_progress_label.visible = has_active_delivery or not has_worker
	_progress_bar.visible = has_active_delivery

	if has_active_delivery:
		_progress_label.text = _room.get_delivery_status_text()
		_progress_bar.value = _room.get_delivery_progress()
	elif not has_worker:
		_progress_label.text = "Assign a worker first"
		_progress_bar.value = 0.0
	else:
		_progress_label.text = ""
		_progress_bar.value = 0.0

	var total_cost := _get_total_cost()
	_order_now_button.disabled = total_cost <= 0 or has_active_delivery or not has_worker
	_order_now_button.text = "Order Now" if total_cost <= 0 else "Order Now (%d$)" % total_cost

	for item_type in _row_nodes.keys():
		var amount: int = int(_draft_amounts.get(item_type, 0))
		var row_nodes: Dictionary = _row_nodes[item_type]
		(row_nodes["amount"] as Label).text = str(amount)
		(row_nodes["minus"] as Button).disabled = amount <= 0

func _adjust_amount(item_type: int, delta: int) -> void:
	var current := int(_draft_amounts.get(item_type, 0))
	_draft_amounts[item_type] = maxi(0, current + delta)
	_refresh()

func _on_new_order_pressed() -> void:
	_is_order_editor_open = not _is_order_editor_open
	_refresh()

func _on_order_now_pressed() -> void:
	if _room == null or not is_instance_valid(_room) or _room.has_active_delivery():
		return

	var total_cost := _get_total_cost()
	if total_cost <= 0:
		return

	if not _room.has_assigned_worker():
		var worker_btn_center = _new_order_button.global_position + _new_order_button.size / 2
		UiNotifications.create_notification_ui("needs worker", worker_btn_center, null, Color.ORANGE)
		return

	if not ResourceHandler.has_money(total_cost):
		var btn_center = _order_now_button.global_position + _order_now_button.size / 2
		UiNotifications.create_notification_ui("not enough money", btn_center, null, Color.ORANGE)
		return

	_order_now_button.disabled = true
	await ResourceHandler.spend_animated(total_cost, _room.get_center_position())
	if _room == null or not is_instance_valid(_room):
		return
	if not _room.place_order(_draft_amounts):
		ResourceHandler.change_money(total_cost)
		var btn_center = _order_now_button.global_position + _order_now_button.size / 2
		UiNotifications.create_notification_ui("needs worker", btn_center, null, Color.ORANGE)
		_refresh()
		return

	_reset_draft_amounts()
	_is_order_editor_open = false
	_refresh()

func _get_total_cost() -> int:
	var total := 0
	for item_type in _draft_amounts.keys():
		var amount := int(_draft_amounts[item_type])
		total += Item.get_trade_price(item_type) * amount
	return total

func _reset_draft_amounts() -> void:
	_draft_amounts.clear()
	for item_type in Item.get_trade_orderable_items():
		_draft_amounts[item_type] = 0
