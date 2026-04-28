class_name ProgressionItemButton
extends Control

static var _selected: ProgressionItemButton = null

signal item_selected(item: ProgressionItem)

@onready var _name_label: Label = $NameLabel
@onready var _icon_rect: TextureRect = $IconRect
@onready var _frame_rect: TextureRect = $FrameRect
@onready var _cost_frame_rect: NinePatchRect = $MarginContainer/CostFrameRect
@onready var _cost_label: Label = $MarginContainer/CostLabel

const FRAME_BIG          := preload("res://assets/sprites/ui/2x/tree_frame_rect.png")
const FRAME_SMALL        := preload("res://assets/sprites/ui/2x/tree_frame_oct.png")
const PROGRESSION_STATE_SHADER := preload("res://assets/shaders/progression_state.gdshader")

var _connector: NinePatchRect = null
var _item: ProgressionItem = null
var _unlocked    := false
var _hovered     := false
var _is_selected := false

func _ready() -> void:
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PROGRESSION_STATE_SHADER
	_frame_rect.material = mat
	mouse_entered.connect(func(): _hovered = true;  _apply_state())
	mouse_exited.connect( func(): _hovered = false; _apply_state())
	ProgressionHandler.item_unlocked.connect(_on_item_unlocked)

func _on_item_unlocked(item: ProgressionItem) -> void:
	if item == _item:
		set_unlocked(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_selected()

func _toggle_selected() -> void:
	if is_instance_valid(_selected) and _selected != self:
		_selected._is_selected = false
		_selected._apply_state()
	_is_selected = not _is_selected if _selected == self else true
	ProgressionItemButton._selected = self if _is_selected else null
	_apply_state()
	item_selected.emit(_item if _is_selected else null)

func setup(item: ProgressionItem, connector: NinePatchRect = null) -> void:
	_item = item
	_connector = connector
	if _connector != null:
		var mat := ShaderMaterial.new()
		mat.shader = PROGRESSION_STATE_SHADER
		_connector.material = mat
	var is_big := item.unlocks_room != null or item.depends_on == null
	_name_label.text = item.display_name
	_icon_rect.texture = item.sprite
	_frame_rect.texture = FRAME_BIG if is_big else FRAME_SMALL
	_cost_label.text = str(item.cost)
	_unlocked = ProgressionHandler.is_item_unlocked(item)
	_apply_state()

func set_unlocked(value: bool) -> void:
	_unlocked = value
	_apply_state()

func _apply_state() -> void:
	$MarginContainer.visible = not _unlocked
	var is_active := _hovered or _is_selected
	var frame_mat := _frame_rect.material as ShaderMaterial
	frame_mat.set_shader_parameter("is_unlocked", _unlocked)
	frame_mat.set_shader_parameter("is_active", is_active)
	_icon_rect.modulate = Color(1,1,1,1.0 if _unlocked else .4)
	_cost_frame_rect.material = frame_mat
	if _connector != null:
		var con_mat := _connector.material as ShaderMaterial
		con_mat.set_shader_parameter("is_unlocked", _unlocked)
		_connector.z_index = 1 if _unlocked else 0
