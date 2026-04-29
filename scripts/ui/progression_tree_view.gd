extends Control

const NODE_W := 48
const NODE_H := 48
const H_GAP := 24
const V_GAP := 48

const CONNECTOR_DOWN    := preload("res://assets/sprites/ui/2x/tree_connector_down.png")
const CONNECTOR_LEFT    := preload("res://assets/sprites/ui/2x/tree_connector_left.png")
const CONNECTOR_RIGHT   := preload("res://assets/sprites/ui/2x/tree_connector_right.png")
const ITEM_BUTTON       := preload("res://scenes/ui/progression_item_button.tscn")
const BTN_FILLED        := preload("res://assets/sprites/ui/2x/tree_filled_button.png")
const BTN_EMPTY         := preload("res://assets/sprites/ui/2x/tree_empty_button.png")
const TREE_LAYOUTER     := preload("res://scripts/ui/progression_tree_layouter.gd")

const ALL_ITEMS := [
	preload("res://assets/resources/progression/prog_empty_room.tres"),
	preload("res://assets/resources/progression/prog_tables.tres"),
	preload("res://assets/resources/progression/prog_stairs.tres"),
	preload("res://assets/resources/progression/prog_outhouse.tres"),
	preload("res://assets/resources/progression/prog_bar.tres"),
	preload("res://assets/resources/progression/prog_broom_room.tres"),
	preload("res://assets/resources/progression/prog_entertainment.tres"),
	preload("res://assets/resources/progression/prog_horsestand.tres"),
	preload("res://assets/resources/progression/prog_water_tower.tres"),
	preload("res://assets/resources/progression/prog_bed_room.tres"),
	preload("res://assets/resources/progression/prog_storage.tres"),
	preload("res://assets/resources/progression/prog_brewery.tres"),
	preload("res://assets/resources/progression/prog_bouncer.tres"),
	preload("res://assets/resources/progression/prog_gambling.tres"),
	preload("res://assets/resources/progression/prog_stables.tres"),
	preload("res://assets/resources/progression/prog_toilets.tres"),
	preload("res://assets/resources/progression/prog_aging_cellar.tres"),
	preload("res://assets/resources/progression/prog_destillery.tres"),
	preload("res://assets/resources/progression/prog_prison.tres"),
	preload("res://assets/resources/progression/prog_safe.tres"),
	preload("res://assets/resources/progression/prog_bath.tres"),
	preload("res://assets/resources/progression/prog_big_brewer.tres"),
	preload("res://assets/resources/progression/prog_big_table.tres"),
	preload("res://assets/resources/progression/prog_stove.tres"),
	preload("res://assets/resources/progression/prog_big_bucket.tres"),
	preload("res://assets/resources/progression/prog_beer_barrel_holder.tres"),
	preload("res://assets/resources/progression/prog_whiskey_shelf.tres"),
	preload("res://assets/resources/progression/prog_triple_bunk_bed.tres"),
	preload("res://assets/resources/progression/prog_trade_office.tres"),
]

@onready var _pan_canvas:      PanCanvas     = $MarginContainer/MarginContainer/VBoxContainer/PanCanvas
@onready var _content:        Control       = $MarginContainer/MarginContainer/VBoxContainer/PanCanvas/Content
@onready var _sidebar:        Control       = $MarginContainer/SidePanel
@onready var _close_button:   Button        = %CloseButton
@onready var _points_pill:    Control       = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer
@onready var _points_label:   RichTextLabel = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/Label
@onready var _points_btn:     NinePatchRect = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/NinePatchRect

var _children_map: Dictionary = {}
var _positions: Dictionary = {}
var _buttons: Dictionary = {}
var _connectors: Dictionary = {}
var _selected_item: ProgressionItem = null
var _was_affordable: Dictionary = {}
var _points_pulse_tween: Tween
var _open_buildup_tweens: Array = []

func _ready() -> void:
	var tree_layout = TREE_LAYOUTER.new(ALL_ITEMS, NODE_W, NODE_H, H_GAP, V_GAP)
	tree_layout.build()
	_children_map = tree_layout.children_map
	_positions = tree_layout.positions
	tree_layout.spawn_connectors(_content, CONNECTOR_DOWN, CONNECTOR_LEFT, CONNECTOR_RIGHT)
	_connectors = tree_layout.connectors
	_spawn_buttons()
	_sidebar.z_index = 2
	_close_button.pressed.connect(hide)
	_pan_canvas.blank_left_clicked.connect(_clear_selection)
	_pan_canvas.blank_right_clicked.connect(_clear_selection)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_refresh_points_pill_pivot")
	_sidebar.buy_feedback_requested.connect(_on_sidebar_buy_feedback_requested)
	ProgressionHandler.item_unlocked.connect(_on_item_unlocked)
	ProgressionHandler.points_changed.connect(_on_points_changed)
	_on_points_changed(ProgressionHandler.get_points())

func _on_points_changed(pts: int) -> void:
	var has_points := pts > 0
	if has_points:
		_points_label.text = "Points available: [color=#ff0055]%d[/color]" % pts
	else:
		_points_label.text = "[color=#888888]Points available: 0[/color]"
	_points_btn.texture = BTN_FILLED if has_points else BTN_EMPTY
	(_points_btn.material as ShaderMaterial).set_shader_parameter("is_unlocked", has_points)
	_refresh_affordable_states()

func _on_item_selected(item: ProgressionItem) -> void:
	_selected_item = item
	_sidebar.on_item_selected(item)
	_apply_focus_for_selection(item)

func _clear_selection() -> void:
	if _selected_item != null and _buttons.has(_selected_item):
		(_buttons[_selected_item] as ProgressionItemButton).force_deselect()
	_selected_item = null
	_sidebar.on_item_selected(null)
	_apply_focus_for_selection(null)

func _apply_focus_for_selection(item: ProgressionItem) -> void:
	var highlighted_items := {}
	var use_focus_path := item != null and not ProgressionHandler.is_item_unlocked(item)
	if use_focus_path:
		var current: ProgressionItem = item
		while current != null:
			highlighted_items[current] = true
			current = current.depends_on

	for button_item in _buttons.keys():
		var button := _buttons[button_item] as ProgressionItemButton
		var highlighted := highlighted_items.has(button_item)
		button.set_focus_state(use_focus_path and not highlighted, highlighted)

func _refresh_affordable_states() -> void:
	for item: ProgressionItem in ALL_ITEMS:
		var affordable := _is_item_affordable(item)
		var was_affordable: bool = _was_affordable.get(item, affordable)
		if affordable and not was_affordable and _buttons.has(item):
			(_buttons[item] as ProgressionItemButton).play_cost_ready_pulse()
		_was_affordable[item] = affordable

func _is_item_affordable(item: ProgressionItem) -> bool:
	if ProgressionHandler.is_item_unlocked(item):
		return false
	var dependency_met := item.depends_on == null or ProgressionHandler.is_item_unlocked(item.depends_on)
	return dependency_met and ProgressionHandler.get_points() >= item.cost

func _on_item_unlocked(item: ProgressionItem) -> void:
	var dependency: ProgressionItem = item.depends_on
	if dependency != null and _buttons.has(dependency):
		(_buttons[dependency] as ProgressionItemButton).play_path_pulse()
		_pulse_connector(item, 0.05)
	if _buttons.has(item):
		(_buttons[item] as ProgressionItemButton).play_unlock_pulse(0.1 if dependency != null else 0.0)
	_refresh_affordable_states()
	_apply_focus_for_selection(_selected_item)
	_pulse_points_pill(false)

func _pulse_connector(item: ProgressionItem, delay: float = 0.0) -> void:
	var connector := _connectors.get(item) as NinePatchRect
	if connector == null:
		return
	var material := connector.material as ShaderMaterial
	if material == null:
		return
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func(): material.set_shader_parameter("is_active", true))
	tween.tween_interval(0.12)
	tween.tween_callback(func(): material.set_shader_parameter("is_active", false))

func _on_sidebar_buy_feedback_requested(item: ProgressionItem, reason: String) -> void:
	if reason == "points":
		_pulse_points_pill(true)
		if _buttons.has(item):
			(_buttons[item] as ProgressionItemButton).play_cost_error_pulse()
	elif reason == "dependency":
		if item.depends_on != null and _buttons.has(item.depends_on):
			var dependency_button := _buttons[item.depends_on] as ProgressionItemButton
			dependency_button.force_select()
			_on_item_selected(item.depends_on)
			dependency_button.play_path_pulse()

func _pulse_points_pill(error: bool) -> void:
	if _points_pulse_tween != null:
		_points_pulse_tween.kill()
	_points_pill.scale = Vector2.ONE
	_points_pill.modulate = Color.WHITE
	var tint := Color(1.0, 0.72, 0.72, 1.0) if error else Color(1.0, 0.92, 0.92, 1.0)
	var tween := create_tween()
	tween.tween_property(_points_pill, "scale", Vector2(1.06, 1.06), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_points_pill, "modulate", tint, 0.06)
	tween.tween_property(_points_pill, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_points_pill, "modulate", Color.WHITE, 0.08)
	_points_pulse_tween = tween

func _refresh_points_pill_pivot() -> void:
	_points_pill.pivot_offset = _points_pill.size * 0.5

func _on_visibility_changed() -> void:
	_clear_open_buildup_tweens()
	_restore_open_buildup_rest_state()
	if visible:
		_play_open_buildup()

func _play_open_buildup() -> void:
	_points_pill.scale = Vector2(0.96, 0.96)
	_points_pill.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	var pill_tween := create_tween()
	pill_tween.tween_property(_points_pill, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pill_tween.parallel().tween_property(_points_pill, "self_modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_track_open_buildup_tween(pill_tween)

	if _sidebar.visible:
		_sidebar.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		var sidebar_tween := create_tween()
		sidebar_tween.tween_interval(0.08)
		sidebar_tween.tween_property(_sidebar, "self_modulate:a", 1.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_track_open_buildup_tween(sidebar_tween)

	for item: ProgressionItem in ALL_ITEMS:
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
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(button, "position", target_position, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "self_modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_track_open_buildup_tween(tween)

func _play_open_buildup_for_connector(item: ProgressionItem, connector: NinePatchRect) -> void:
	var delay := 0.1 + _get_item_depth(item) * 0.1
	connector.visible = false
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(connector.show)
	_track_open_buildup_tween(tween)

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
	_points_pill.scale = Vector2.ONE
	_points_pill.self_modulate = Color.WHITE
	_sidebar.self_modulate = Color.WHITE
	for item: ProgressionItem in ALL_ITEMS:
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
	for item: ProgressionItem in ALL_ITEMS:
		var btn: ProgressionItemButton = ITEM_BUTTON.instantiate() as ProgressionItemButton
		btn.position = _positions[item]
		_content.add_child(btn)
		btn.setup(item, _connectors.get(item))
		btn.item_selected.connect(_on_item_selected)
		btn.secondary_clicked.connect(_clear_selection)
		_buttons[item] = btn
