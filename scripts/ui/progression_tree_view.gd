extends Control

const NODE_W := 58
const NODE_H := 58
const H_GAP := 24
const V_GAP := 48

const CONNECTOR_DOWN := preload("res://assets/sprites/ui/2x/tree_connector_down.png")
const CONNECTOR_LEFT := preload("res://assets/sprites/ui/2x/tree_connector_left.png")
const CONNECTOR_RIGHT := preload("res://assets/sprites/ui/2x/tree_connector_right.png")
const ITEM_BUTTON := preload("res://scenes/ui/progression_item_button.tscn")
const BTN_FILLED := preload("res://assets/sprites/ui/2x/tree_filled_button.png")
const BTN_EMPTY := preload("res://assets/sprites/ui/2x/tree_empty_button.png")
const TREE_LAYOUTER := preload("res://scripts/ui/progression_tree_layouter.gd")

@onready var _pan_canvas: PanCanvas = $MarginContainer/MarginContainer/VBoxContainer/PanCanvas
@onready var _content: Control = $MarginContainer/MarginContainer/VBoxContainer/PanCanvas/Content
@onready var _sidebar: Control = $MarginContainer/SidePanel
@onready var _close_button: Button = %CloseButton
@onready var _summary_pill: Control = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer
@onready var _summary_label: RichTextLabel = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/Label
@onready var _summary_btn: NinePatchRect = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/NinePatchRect

var _items: Array[ProgressionItem] = []
var _children_map: Dictionary = {}
var _positions: Dictionary = {}
var _buttons: Dictionary = {}
var _connectors: Dictionary = {}
var _selected_item: ProgressionItem = null
var _summary_pulse_tween: Tween
var _open_buildup_tweens: Array = []

func _ready() -> void:
	_items = ProgressionHandler.get_all_items()
	var tree_layout = TREE_LAYOUTER.new(_items, NODE_W, NODE_H, H_GAP, V_GAP)
	tree_layout.build()
	_children_map = tree_layout.children_map
	_positions = tree_layout.positions
	tree_layout.spawn_connectors(_content, CONNECTOR_DOWN, CONNECTOR_LEFT, CONNECTOR_RIGHT)
	_connectors = tree_layout.connectors
	_spawn_buttons()

	_sidebar.z_index = 2
	_close_button.pressed.connect(_on_close_pressed)
	_pan_canvas.blank_left_clicked_signal.connect(_on_blank_left_clicked)
	_pan_canvas.blank_right_clicked_signal.connect(_on_blank_right_clicked)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_refresh_summary_pill_pivot")

	_sidebar.dependency_requested_signal.connect(_focus_dependency_item)
	ProgressionHandler.item_unlocked_signal.connect(_on_item_unlocked)
	ProgressionHandler.item_completed_signal.connect(_on_item_completed)
	_refresh_summary_pill()
	_refresh_shader_time()

func _process(_delta: float) -> void:
	_refresh_shader_time()

func _on_item_selected(item: ProgressionItem) -> void:
	_selected_item = item
	_sidebar.on_item_selected(item)
	_apply_focus_for_selection(item)

func _on_blank_left_clicked() -> void:
	SoundPlayer.play_ui_click_down()
	_clear_selection()

func _on_blank_right_clicked() -> void:
	SoundPlayer.play_ui_click_down()
	_clear_selection()

func _on_close_pressed() -> void:
	SoundPlayer.play_ui_click_up()
	hide()

func _clear_selection() -> void:
	if _selected_item != null and _buttons.has(_selected_item):
		(_buttons[_selected_item] as ProgressionItemButton).force_deselect()
	_selected_item = null
	_sidebar.on_item_selected(null)
	_apply_focus_for_selection(null)

func _apply_focus_for_selection(item: ProgressionItem) -> void:
	var highlighted_items := {}
	var use_focus_path := item != null and not ProgressionHandler.is_item_completed(item)
	if use_focus_path:
		_collect_requirement_items(item, highlighted_items)

	for button_item in _buttons.keys():
		var button := _buttons[button_item] as ProgressionItemButton
		var highlighted := highlighted_items.has(button_item)
		button.set_focus_state(use_focus_path and not highlighted, highlighted)

func _collect_requirement_items(item: ProgressionItem, highlighted_items: Dictionary) -> void:
	if item == null or highlighted_items.has(item):
		return
	highlighted_items[item] = true
	for requirement in item.get_required_items():
		_collect_requirement_items(requirement, highlighted_items)

func _on_item_unlocked(item: ProgressionItem) -> void:
	var dependency: ProgressionItem = item.depends_on
	if dependency != null and _buttons.has(dependency):
		(_buttons[dependency] as ProgressionItemButton).play_path_pulse()
		_pulse_connector(item, 0.05)
	if _buttons.has(item):
		(_buttons[item] as ProgressionItemButton).play_unlock_pulse(0.1 if dependency != null else 0.0)
	_refresh_summary_pill()
	_apply_focus_for_selection(_selected_item)
	_pulse_summary_pill(false)

func _on_item_completed(item: ProgressionItem) -> void:
	if _buttons.has(item):
		(_buttons[item] as ProgressionItemButton).play_unlock_pulse()
	_refresh_summary_pill()
	_apply_focus_for_selection(_selected_item)
	_pulse_summary_pill(true)

func _focus_dependency_item(item: ProgressionItem) -> void:
	if item == null or not _buttons.has(item):
		return
	var dependency_button := _buttons[item] as ProgressionItemButton
	dependency_button.force_select()
	_on_item_selected(item)
	dependency_button.play_path_pulse()

func _pulse_connector(item: ProgressionItem, delay: float = 0.0) -> void:
	var connector := _connectors.get(item) as NinePatchRect
	if connector == null:
		return
	var material := connector.material as ShaderMaterial
	if material == null:
		return
	var tween := _create_ui_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func(): material.set_shader_parameter("is_active", true))
	tween.tween_interval(0.12)
	tween.tween_callback(func(): material.set_shader_parameter("is_active", false))

func _refresh_summary_pill() -> void:
	var completed := ProgressionHandler.get_completed_item_count()
	var total := _items.size()
	var all_done := completed >= total and total > 0
	_summary_label.text = "Groups completed: [color=#ff0055]%d/%d[/color]" % [completed, total]
	_summary_btn.texture = BTN_FILLED if all_done else BTN_EMPTY
	(_summary_btn.material as ShaderMaterial).set_shader_parameter("is_unlocked", all_done)

func _pulse_summary_pill(completed_group: bool) -> void:
	if _summary_pulse_tween != null:
		_summary_pulse_tween.kill()
	_summary_pill.scale = Vector2.ONE
	_summary_pill.modulate = Color.WHITE
	var tint := Color(1.0, 0.95, 0.85, 1.0) if completed_group else Color(0.92, 1.0, 0.92, 1.0)
	var tween := _create_ui_tween()
	tween.tween_property(_summary_pill, "scale", Vector2(1.06, 1.06), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_summary_pill, "modulate", tint, 0.06)
	tween.tween_property(_summary_pill, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_summary_pill, "modulate", Color.WHITE, 0.08)
	_summary_pulse_tween = tween

func _refresh_summary_pill_pivot() -> void:
	_summary_pill.pivot_offset = _summary_pill.size * 0.5

func _on_visibility_changed() -> void:
	_clear_open_buildup_tweens()
	_restore_open_buildup_rest_state()
	if visible:
		_refresh_item_buttons()
		_play_open_buildup()

func _play_open_buildup() -> void:
	_summary_pill.scale = Vector2(0.96, 0.96)
	_summary_pill.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	var pill_tween := _create_ui_tween()
	pill_tween.tween_property(_summary_pill, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pill_tween.parallel().tween_property(_summary_pill, "self_modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_track_open_buildup_tween(pill_tween)

	if _sidebar.visible:
		_sidebar.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		var sidebar_tween := _create_ui_tween()
		sidebar_tween.tween_interval(0.08)
		sidebar_tween.tween_property(_sidebar, "self_modulate:a", 1.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_track_open_buildup_tween(sidebar_tween)

	for item: ProgressionItem in _items:
		if _buttons.has(item):
			_play_open_buildup_for_button(item, _buttons[item] as ProgressionItemButton)
		if _connectors.has(item):
			_play_open_buildup_for_connector(item, _connectors[item] as NinePatchRect)

func _play_open_buildup_for_button(item: ProgressionItem, button: ProgressionItemButton) -> void:
	var target_position: Vector2 = _positions[item]
	var delay := 0.1 + _get_item_depth(item) * 0.1
	button.position = target_position + Vector2(0.0, 4.0)
	button.scale = Vector2(0.0, 0.0)
	button.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := _create_ui_tween()
	tween.tween_interval(delay)
	tween.tween_property(button, "position", target_position, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "self_modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_track_open_buildup_tween(tween)

func _play_open_buildup_for_connector(item: ProgressionItem, connector: NinePatchRect) -> void:
	var delay := 0.1 + _get_item_depth(item) * 0.1
	connector.visible = false
	var tween := _create_ui_tween()
	tween.tween_interval(delay)
	tween.tween_callback(connector.show)
	_track_open_buildup_tween(tween)

func _create_ui_tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)

func _refresh_shader_time() -> void:
	var material := _summary_btn.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("ui_time", float(Time.get_ticks_msec()) / 1000.0)

func _track_open_buildup_tween(tween: Tween) -> void:
	_open_buildup_tweens.append(tween)
	tween.finished.connect(func():
		_open_buildup_tweens.erase(tween)
	)

func _clear_open_buildup_tweens() -> void:
	for tween in _open_buildup_tweens:
		if tween != null:
			tween.kill()
	_open_buildup_tweens.clear()

func _restore_open_buildup_rest_state() -> void:
	_summary_pill.scale = Vector2.ONE
	_summary_pill.self_modulate = Color.WHITE
	_sidebar.self_modulate = Color.WHITE
	for item: ProgressionItem in _items:
		if _buttons.has(item):
			var button := _buttons[item] as ProgressionItemButton
			button.position = _positions[item]
			button.scale = Vector2.ONE
			button.self_modulate = Color.WHITE
		if _connectors.has(item):
			var connector := _connectors[item] as NinePatchRect
			connector.visible = true
			connector.self_modulate = Color.WHITE

func _get_item_depth(item: ProgressionItem) -> int:
	var depth := 0
	var current: ProgressionItem = item.depends_on
	while current != null:
		depth += 1
		current = current.depends_on
	return depth

func _spawn_buttons() -> void:
	for item: ProgressionItem in _items:
		var btn: ProgressionItemButton = ITEM_BUTTON.instantiate() as ProgressionItemButton
		btn.position = _positions[item]
		_content.add_child(btn)
		btn.setup(item, _connectors.get(item))
		btn.item_selected_signal.connect(_on_item_selected)
		btn.secondary_clicked_signal.connect(_clear_selection)
		_buttons[item] = btn

func _refresh_item_buttons() -> void:
	for button in _buttons.values():
		(button as ProgressionItemButton).refresh_visual_state()
