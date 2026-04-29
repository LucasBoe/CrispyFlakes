class_name ProgressionItemButton
extends Control

static var _selected: ProgressionItemButton = null

signal item_selected(item: ProgressionItem)
signal secondary_clicked

@onready var _name_label: Label = $NameLabel
@onready var _icon_rect: TextureRect = $IconRect
@onready var _frame_rect: TextureRect = $FrameRect
@onready var _cost_badge: Control = $MarginContainer
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
var _path_highlighted := false
var _dimmed := false
var _flash_active := false
var _frame_tween: Tween
var _cost_tween: Tween
var _cost_badge_rest_position := Vector2.ZERO

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
	call_deferred("_refresh_visual_pivots")

func _refresh_visual_pivots() -> void:
	pivot_offset = size * 0.5
	_cost_badge.pivot_offset = _cost_badge.size * 0.5
	_cost_badge_rest_position = _cost_badge.position

func _on_item_unlocked(item: ProgressionItem) -> void:
	if item == _item:
		set_unlocked(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and mouse_button_event.pressed:
			_toggle_selected()
		elif mouse_button_event.button_index == MOUSE_BUTTON_RIGHT and mouse_button_event.pressed:
			secondary_clicked.emit()

func _toggle_selected() -> void:
	if is_instance_valid(_selected) and _selected != self:
		_selected._is_selected = false
		_selected._apply_state()
	_is_selected = not _is_selected if _selected == self else true
	ProgressionItemButton._selected = self if _is_selected else null
	_apply_state()
	item_selected.emit(_item if _is_selected else null)

func force_select() -> void:
	if is_instance_valid(_selected) and _selected != self:
		_selected._is_selected = false
		_selected._apply_state()
	_is_selected = true
	ProgressionItemButton._selected = self
	_apply_state()

func force_deselect() -> void:
	_is_selected = false
	if ProgressionItemButton._selected == self:
		ProgressionItemButton._selected = null
	_apply_state()

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

func set_focus_state(dimmed: bool, path_highlighted: bool) -> void:
	_dimmed = dimmed
	_path_highlighted = path_highlighted
	_apply_state()

func play_unlock_pulse(delay: float = 0.0) -> void:
	_play_frame_pulse(Vector2(1.1, 1.1), Vector2(0.96, 0.96), delay)

func play_path_pulse(delay: float = 0.0) -> void:
	_play_frame_pulse(Vector2(1.06, 1.06), Vector2.ONE, delay)

func play_cost_ready_pulse(delay: float = 0.0) -> void:
	if _unlocked or not _cost_badge.visible:
		return
	if _cost_tween != null:
		_cost_tween.kill()
	_cost_badge.scale = Vector2.ONE
	_cost_badge.modulate = Color.WHITE
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(_cost_badge, "scale", Vector2(1.14, 1.14), 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cost_badge, "scale", Vector2.ONE, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_cost_badge, "modulate", Color(1.0, 0.85, 0.85, 1.0), 0.06)
	tween.tween_property(_cost_badge, "modulate", Color.WHITE, 0.08)
	_cost_tween = tween

func play_cost_error_pulse() -> void:
	if _unlocked or not _cost_badge.visible:
		return
	if _cost_tween != null:
		_cost_tween.kill()
	_cost_badge.position = _cost_badge_rest_position
	_cost_badge.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_cost_badge, "position:x", _cost_badge_rest_position.x - 2.0, 0.03)
	tween.parallel().tween_property(_cost_badge, "modulate", Color(1.0, 0.55, 0.55, 1.0), 0.05)
	tween.tween_property(_cost_badge, "position:x", _cost_badge_rest_position.x + 2.0, 0.03)
	tween.tween_property(_cost_badge, "position:x", _cost_badge_rest_position.x - 1.0, 0.02)
	tween.tween_property(_cost_badge, "position:x", _cost_badge_rest_position.x, 0.02)
	tween.tween_property(_cost_badge, "modulate", Color.WHITE, 0.08)
	_cost_tween = tween

func _play_frame_pulse(peak_scale: Vector2, settle_scale: Vector2, delay: float) -> void:
	if _frame_tween != null:
		_frame_tween.kill()
	scale = Vector2.ONE
	_flash_active = false
	_apply_state()
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func():
		_flash_active = true
		_apply_state()
	)
	tween.tween_property(self, "scale", peak_scale, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", settle_scale, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_flash_active = false
		_apply_state()
	)
	_frame_tween = tween

func _apply_state() -> void:
	$MarginContainer.visible = not _unlocked
	var show_active_state := _flash_active or (not _unlocked and (_hovered or _is_selected or _path_highlighted))
	var brightness := 1.0 if _unlocked else (0.45 if _dimmed else 1.0)
	modulate = Color(brightness, brightness, brightness, 1.0)
	var frame_mat := _frame_rect.material as ShaderMaterial
	frame_mat.set_shader_parameter("is_unlocked", _unlocked)
	frame_mat.set_shader_parameter("is_active", show_active_state)
	_icon_rect.modulate = Color(1,1,1,1.0 if _unlocked else .4)
	_cost_frame_rect.material = frame_mat
	if _connector != null:
		var con_mat := _connector.material as ShaderMaterial
		con_mat.set_shader_parameter("is_unlocked", _unlocked)
		con_mat.set_shader_parameter("is_active", _flash_active or (not _unlocked and (_path_highlighted or _is_selected)))
		_connector.z_index = 1 if _unlocked else 0
