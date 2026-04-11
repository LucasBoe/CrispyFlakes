extends MarginContainer
class_name UISelectionRoomModules

@onready var details_window = $Control
@onready var details_window_header = $Control/MarginContainer/MarginContainer/VBoxContainer/Label
@onready var details_window_describtion = $Control/MarginContainer/MarginContainer/VBoxContainer/RichTextLabel
@onready var details_window_button = $Control/MarginContainer/MarginContainer/VBoxContainer/Button

@onready var branch_dummy = $HBoxContainer/VBoxContainer
# child 0 is button: child 1 is connector
# for each new module, duplicate both until last, there no connector is needed

@onready var module_button_base_active = preload("res://assets/sprites/ui/module_active.png") # base used for modules bought
@onready var module_button_base_inactive = preload("res://assets/sprites/ui/module_inactive.png") # base for inactive modules

var _selected_module = null
var _current_room: RoomBase = null
var _branch_instances: Array = []
var _module_buttons: Dictionary = {}  # module node -> Button

func _ready() -> void:
	branch_dummy.hide()
	details_window.hide()
	details_window_describtion.bbcode_enabled = true
	hide()
	details_window_button.pressed.connect(_on_buy_pressed)

func populate(room: Node2D) -> void:
	_clear()
	_current_room = room

	var modules_root = room.get_node_or_null("ModulesRoot")
	if modules_root == null or modules_root.get_child_count() == 0:
		hide()
		return

	show()

	var groups = modules_root.get_children()
	for i in groups.size():
		_add_branch(groups[i], i == groups.size() - 1)


func _add_branch(group: Node, is_last_group: bool) -> void:
	var branch = branch_dummy.duplicate() as VBoxContainer
	branch_dummy.get_parent().add_child(branch)
	branch.show()
	_branch_instances.append(branch)

	var template_btn = branch.get_child(0) as Button
	var template_conn = branch.get_child(1) as TextureRect

	var modules = group.get_children()
	for j in modules.size():
		var module = modules[j]
		var is_last_module = j == modules.size() - 1

		# Add button — reuse template for j=0, duplicate for the rest
		var btn: Button
		if j == 0:
			btn = template_btn
		else:
			btn = template_btn.duplicate() as Button
			branch.add_child(btn)

		btn.show()
		if module.icon != null:
			btn.icon = module.icon
		_apply_button_style(btn, module.bought)
		btn.pressed.connect(_select_module.bind(module))
		btn.mouse_entered.connect(_on_module_hover.bind(module))
		btn.mouse_exited.connect(_on_module_hover_exit)
		_module_buttons[module] = btn

		# Add connector after button, except after the last module
		if is_last_module:
			# j=0 with only one module: hide the template connector
			if j == 0:
				template_conn.hide()
			# j>0: no connector was added, nothing to do
		else:
			# Reuse template connector after btn0; duplicate for subsequent buttons
			var conn: TextureRect
			if j == 0:
				conn = template_conn
			else:
				conn = template_conn.duplicate() as TextureRect
				branch.add_child(conn)
			conn.show()

func _apply_button_style(btn: Button, is_active: bool) -> void:
	var tex = module_button_base_active if is_active else module_button_base_inactive
	var normal = _make_style(tex)
	if not is_active:
		normal.modulate_color = Color(0.5019608, 0.4862745, 0.45882353, 1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("pressed", _make_style(tex))
	btn.add_theme_stylebox_override("hover", _make_style(tex))

func _make_style(tex: Texture2D) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 1.0
	style.texture_margin_top = 1.0
	style.texture_margin_right = 1.0
	style.texture_margin_bottom = 1.0
	return style

func _module_text(module) -> String:
	var price = "[color=#ffe432]" + str(module.price) + "$[/color]"
	var price_line = "\nbought (" + price + ")" if module.bought else "\n" + price
	return module.describtion + price_line

func _on_module_hover(module) -> void:
	details_window.show()
	details_window_describtion.text = _module_text(module)
	details_window_header.text = module.module_name
	details_window_header.visible = module.module_name != ""
	if module == _selected_module:
		details_window_button.show()
		_refresh_buy_button()
	else:
		details_window_button.hide()

func _on_module_hover_exit() -> void:
	if _selected_module != null:
		_show_selected()
	else:
		details_window.hide()

func _select_module(module) -> void:
	_selected_module = module
	_show_selected()

func _show_selected() -> void:
	details_window.show()
	details_window_describtion.text = _module_text(_selected_module)
	details_window_button.show()
	_refresh_buy_button()

func _get_buy_label() -> String:
	var group = _selected_module.get_parent()
	var modules = group.get_children()
	var selected_index = modules.find(_selected_module)
	for i in modules.size():
		if i == selected_index or not modules[i].bought:
			continue
		return "Upgrade" if i < selected_index else "Downgrade"
	return "Buy"

func _refresh_buy_button() -> void:
	if _selected_module == null:
		return
	if _selected_module.bought:
		details_window_button.hide()
	else:
		details_window_button.show()
		details_window_button.text = _get_buy_label()
		details_window_button.disabled = false

func _on_buy_pressed() -> void:
	if _selected_module == null or _selected_module.bought:
		return
	if not ResourceHandler.has_money(_selected_module.price):
		var btn_center = details_window_button.global_position + details_window_button.size / 2
		UiNotifications.create_notification_ui("not enough money", btn_center, null, Color.ORANGE)
		return

	# Update buttons immediately
	var group = _selected_module.get_parent()
	for module in group.get_children():
		if module == _selected_module:
			continue
		if module.bought:
			if _module_buttons.has(module):
				_apply_button_style(_module_buttons[module], false)
	if _module_buttons.has(_selected_module):
		_apply_button_style(_module_buttons[_selected_module], true)
	_refresh_buy_button()

	# Wait for animation, then update room visuals
	var purchased = _selected_module
	var world_pos = _current_room.get_center_position() if is_instance_valid(_current_room) else global_position
	await ResourceHandler.spend_animated(purchased.price, world_pos)

	for module in group.get_children():
		if module == purchased:
			continue
		if module.bought:
			module.set_bought(false)
	purchased.set_bought(true)

func _clear() -> void:
	_selected_module = null
	_current_room = null
	_module_buttons.clear()
	for branch in _branch_instances:
		if is_instance_valid(branch):
			branch.queue_free()
	_branch_instances.clear()
	details_window.hide()
