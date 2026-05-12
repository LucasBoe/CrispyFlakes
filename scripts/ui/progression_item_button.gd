class_name ProgressionItemButton
extends Control

static var _selected: ProgressionItemButton = null

signal item_selected(item: ProgressionItem)
signal secondary_clicked

@onready var _name_label: Label = $NameLabel
@onready var _preview_row: HBoxContainer = $PreviewRow
@onready var _preview_slots: Array[TextureRect] = [
	$PreviewRow/Preview1,
	$PreviewRow/Preview2,
	$PreviewRow/Preview3,
	$PreviewRow/Preview4,
]
@onready var _preview_markers: Array[TextureRect] = [
	$PreviewRow/Preview1/Marker,
	$PreviewRow/Preview2/Marker,
	$PreviewRow/Preview3/Marker,
	$PreviewRow/Preview4/Marker,
]
@onready var _preview_dividers: Array[TextureRect] = [
	$PreviewRow/Divider1,
	$PreviewRow/Divider2,
	$PreviewRow/Divider3,
]
@onready var _frame_rect: NinePatchRect = $FrameRect
@onready var _cost_badge: Control = $MarginContainer
@onready var _cost_frame_rect: NinePatchRect = $MarginContainer/CostFrameRect
@onready var _cost_border_rect: NinePatchRect = $MarginContainer/MarginContainer/NinePatchRect
@onready var _cost_label: Label = $MarginContainer/MarginContainer/CostLabel

const PREVIEW_SIZE := 48.0
const DIVIDER_WIDTH := 5.0
const FRAME_PADDING := 5.0
const FRAME_HEIGHT := 58.0
const FRAME_BIG          := preload("res://assets/sprites/ui/2x/tree_frame_rect.png")
const FRAME_SMALL        := preload("res://assets/sprites/ui/2x/tree_frame_oct.png")
const PROGRESSION_STATE_SHADER := preload("res://assets/shaders/progression_state.gdshader")
const DONE_MARKER_DONE := preload("res://assets/sprites/ui/2x/tree_done_marker_done.png")
const DONE_MARKER_NOT_DONE := preload("res://assets/sprites/ui/2x/tree_done_marker_not_done.png")
const HIDDEN_LABEL := "?"
const INCOMPLETE_COUNT_COLOR := Color8(0xff, 0x00, 0x55)
const COMPLETE_COUNT_COLOR := Color8(0x97, 0xc6, 0x5d)

var _connector: NinePatchRect = null
var _item: ProgressionItem = null
var _unlocked    := false
var _completed   := false
var _revealed    := false
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
	for divider in _preview_dividers:
		divider.material = mat
	_refresh_shader_time()
	mouse_entered.connect(func(): _hovered = true;  _apply_state())
	mouse_exited.connect( func(): _hovered = false; _apply_state())
	ProgressionHandler.item_unlocked.connect(_on_item_unlocked)
	ProgressionHandler.item_completed.connect(_on_item_completed)
	call_deferred("_refresh_visual_pivots")

func _process(_delta: float) -> void:
	_refresh_shader_time()
	_apply_state()

func _refresh_visual_pivots() -> void:
	pivot_offset = size * 0.5
	_cost_badge.pivot_offset = _cost_badge.size * 0.5
	_cost_badge_rest_position = _cost_badge.position

static func get_preview_count(item: ProgressionItem) -> int:
	if item == null:
		return 1
	return clampi(item.get_content_count(), 1, 4)

static func get_visual_width(item: ProgressionItem) -> float:
	var preview_count := get_preview_count(item)
	return PREVIEW_SIZE * preview_count + (DIVIDER_WIDTH - 2.0) * maxf(0.0, preview_count - 1.0) + FRAME_PADDING * 2.0

func _on_item_unlocked(item: ProgressionItem) -> void:
	_revealed = ProgressionHandler.is_item_revealed(_item)
	if item == _item:
		set_unlocked(true)
	else:
		_apply_state()

func _on_item_completed(item: ProgressionItem) -> void:
	if item == _item:
		set_completed(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and mouse_button_event.pressed:
			SoundPlayer.play_ui_click_down()
			_toggle_selected()
		elif mouse_button_event.button_index == MOUSE_BUTTON_RIGHT and mouse_button_event.pressed:
			SoundPlayer.play_ui_click_down()
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
		_refresh_shader_time()
	var visual_width := get_visual_width(item)
	custom_minimum_size = Vector2(visual_width, FRAME_HEIGHT)
	size = custom_minimum_size
	var is_big := item.has_content() or item.depends_on == null
	_name_label.text = item.display_name
	_frame_rect.texture = FRAME_BIG if is_big else FRAME_SMALL
	_unlocked = ProgressionHandler.is_item_unlocked(item)
	_completed = ProgressionHandler.is_item_completed(item)
	_revealed = ProgressionHandler.is_item_revealed(item)
	refresh_visual_state()

func refresh_visual_state() -> void:
	if _item == null:
		return
	_unlocked = ProgressionHandler.is_item_unlocked(_item)
	_completed = ProgressionHandler.is_item_completed(_item)
	_revealed = ProgressionHandler.is_item_revealed(_item)
	_apply_preview_textures()
	_apply_state()

func set_unlocked(value: bool) -> void:
	_unlocked = value
	_apply_state()

func set_completed(value: bool) -> void:
	_completed = value
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
	if _completed or not _cost_badge.visible:
		return
	if _cost_tween != null:
		_cost_tween.kill()
	_cost_badge.scale = Vector2.ONE
	_cost_badge.modulate = Color.WHITE
	var tween := _create_ui_tween()
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
	if _completed or not _cost_badge.visible:
		return
	if _cost_tween != null:
		_cost_tween.kill()
	_cost_badge.position = _cost_badge_rest_position
	_cost_badge.modulate = Color.WHITE
	var tween := _create_ui_tween()
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
	var tween := _create_ui_tween()
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

func _create_ui_tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)

func _refresh_shader_time() -> void:
	var ui_time := float(Time.get_ticks_msec()) / 1000.0
	_set_shader_ui_time(_frame_rect.material, ui_time)
	if _connector != null:
		_set_shader_ui_time(_connector.material, ui_time)

func _set_shader_ui_time(material: Material, ui_time: float) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("ui_time", ui_time)

func _apply_preview_textures() -> void:
	var preview_textures: Array[Texture2D] = []
	var preview_built_states: Array[bool] = []
	if _item != null:
		for room in _item.get_unlocked_rooms():
			var texture: Texture =room.get_display_icon()
			if texture != null:
				preview_textures.append(texture)
				preview_built_states.append(ProgressionHandler.is_content_built(room))
		for data in _item.get_unlocked_infrastructure():
			var texture: Texture =data.get_display_icon()
			if texture != null:
				preview_textures.append(texture)
				preview_built_states.append(ProgressionHandler.is_content_built(data))

	for i in range(_preview_slots.size()):
		if i < preview_textures.size():
			_preview_slots[i].texture = preview_textures[i]
			_preview_slots[i].show()
			_preview_markers[i].texture = DONE_MARKER_DONE if preview_built_states[i] else DONE_MARKER_NOT_DONE
			_preview_markers[i].visible = _unlocked
		else:
			_preview_slots[i].hide()
			_preview_markers[i].hide()

	for i in range(_preview_dividers.size()):
		_preview_dividers[i].visible = i < preview_textures.size() - 1

func _apply_state() -> void:
	var total := ProgressionHandler.get_item_total_content_count(_item) if _item != null else 0
	var built := ProgressionHandler.get_item_completed_content_count(_item) if _item != null else 0
	_revealed = ProgressionHandler.is_item_revealed(_item)
	_cost_label.text = "%d/%d" % [built, total] if total > 0 and _revealed else ""
	_cost_label.modulate = COMPLETE_COUNT_COLOR if _completed else INCOMPLETE_COUNT_COLOR
	$MarginContainer.visible = _revealed and _unlocked and total > 0
	_cost_frame_rect.visible = true
	_cost_border_rect.visible = not _completed
	var show_active_state := _revealed and (_flash_active or (not _completed and (_hovered or _is_selected or _path_highlighted)))
	var brightness := 1.0 if _revealed and _unlocked else (0.45 if _dimmed else 1.0)
	modulate = Color(brightness, brightness, brightness, 1.0)
	_name_label.text = _item.display_name if _revealed else HIDDEN_LABEL
	_name_label.visible = not _revealed
	var frame_mat := _frame_rect.material as ShaderMaterial
	frame_mat.set_shader_parameter("is_unlocked", _unlocked)
	frame_mat.set_shader_parameter("is_active", show_active_state)
	_preview_row.visible = _revealed
	for preview in _preview_slots:
		preview.modulate = Color(1, 1, 1, 1.0 if _unlocked or _completed else 0.4)
	for marker in _preview_markers:
		if marker.visible or marker.get_parent().visible:
			marker.visible = _unlocked and marker.get_parent().visible
	_cost_frame_rect.material = frame_mat
	if _connector != null:
		var con_mat := _connector.material as ShaderMaterial
		con_mat.set_shader_parameter("is_unlocked", _unlocked)
		con_mat.set_shader_parameter("is_active", _flash_active or (not _completed and (_path_highlighted or _is_selected)))
		_connector.z_index = 1 if _unlocked or _completed else 0
