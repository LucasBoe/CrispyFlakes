extends Control
class_name UIEncounter

signal choice_selected(choice: Dictionary)

const _PANEL_SCREEN_MARGIN := 8.0
const _NPC_LINE_OFFSET := Vector2(0, -24)
const _FOCUS_ZOOM := 4.0
const _FOCUS_OFFSET := Vector2(0, -16)

@onready var root: MarginContainer = $MarginContainer
@onready var dialogue_label: RichTextLabel = %Container.get_node("RichTextLabel")
@onready var buttons: HFlowContainer = %Buttons
@onready var line: PixelLine = $MarginContainer/Control/LineAnchor/Line

var _target: Node2D = null
var _active := false
var _selected_choice: Dictionary = {}

func _ready() -> void:
	hide()
	_clear_buttons()

func start_encounter(target: Node2D, encounter: Dictionary) -> Dictionary:
	if _active:
		return {}

	_active = true
	_target = target
	_selected_choice = {}
	dialogue_label.text = str(encounter.get("line", ""))
	_rebuild_buttons(encounter.get("choices", []))
	_update_position()
	show()

	if is_instance_valid(Camera) and Camera.has_method("push_focus_lock"):
		Camera.push_focus_lock(self, target, _FOCUS_ZOOM, _FOCUS_OFFSET)
	TimeHandler.push_pause_lock(self)

	await choice_selected
	_close()
	return _selected_choice

func show_outcome(target: Node2D, text: String) -> void:
	if _active:
		return

	_active = true
	_target = target
	_selected_choice = {}
	dialogue_label.text = text
	_rebuild_buttons([{
		"text": "OK",
		"price_label": "",
	}])
	_update_position()
	show()

	if is_instance_valid(Camera) and Camera.has_method("push_focus_lock"):
		Camera.push_focus_lock(self, target, _FOCUS_ZOOM, _FOCUS_OFFSET)
	TimeHandler.push_pause_lock(self)

	await choice_selected
	_close()

func is_active() -> bool:
	return _active

func _process(_delta: float) -> void:
	if _active:
		_update_position()

func _rebuild_buttons(choices: Array) -> void:
	_clear_buttons()
	for choice in choices:
		var button := Button.new()
		button.theme = dialogue_label.theme
		var price_label := str(choice.get("price_label", ""))
		button.text = str(choice.get("text", ""))
		if price_label != "":
			button.text += " (%s)" % price_label
		button.pressed.connect(_on_choice_pressed.bind(choice))
		buttons.add_child(button)

func _clear_buttons() -> void:
	if buttons == null:
		return
	for child in buttons.get_children():
		child.queue_free()

func _on_choice_pressed(choice: Dictionary) -> void:
	_selected_choice = choice
	choice_selected.emit(choice)

func _close() -> void:
	TimeHandler.pop_pause_lock(self)
	if is_instance_valid(Camera) and Camera.has_method("pop_focus_lock"):
		Camera.pop_focus_lock(self)
	hide()
	_clear_buttons()
	_target = null
	_active = false

func _update_position() -> void:
	if not is_instance_valid(_target):
		return

	var target_ui_position: Vector2 = Util.world_to_ui_position(_target.global_position + _NPC_LINE_OFFSET, self, Camera)
	var panel_size := root.size
	var viewport_size := get_viewport().get_visible_rect().size
	var desired_position: Vector2 = target_ui_position - Vector2(panel_size.x * 0.5, panel_size.y + 34.0)
	desired_position.x = clampf(desired_position.x, _PANEL_SCREEN_MARGIN, viewport_size.x - panel_size.x - _PANEL_SCREEN_MARGIN)
	desired_position.y = clampf(desired_position.y, _PANEL_SCREEN_MARGIN, viewport_size.y - panel_size.y - _PANEL_SCREEN_MARGIN)
	root.global_position = desired_position

	line.global_position = Vector2(
		clampf(target_ui_position.x, root.global_position.x + 8.0, root.global_position.x + panel_size.x - 8.0),
		root.global_position.y + panel_size.y
	)
	line.target_position = target_ui_position
