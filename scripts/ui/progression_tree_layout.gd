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
]

@onready var _content:        Control       = $MarginContainer/MarginContainer/VBoxContainer/PanCanvas/Content
@onready var _sidebar:        Control       = $SidePanel
@onready var _points_label:   RichTextLabel = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/MarginContainer/Label
@onready var _points_btn:     NinePatchRect = $MarginContainer/MarginContainer/VBoxContainer/MarginContainer/NinePatchRect

var _children_map: Dictionary = {}
var _positions: Dictionary = {}
var _connectors: Dictionary = {}

func _ready() -> void:
	_build_children_map()
	var root: ProgressionItem = _find_root()
	_compute_layout(root, 0.0, 0)
	_normalize_positions()
	_spawn_connectors(root)
	_spawn_buttons()
	ProgressionHandler.points_changed.connect(_on_points_changed)
	_on_points_changed(ProgressionHandler.get_points())

func _on_points_changed(pts: int) -> void:
	_points_label.text = "Points available: [color=#ff0055]%d[/color]" % pts
	var has_points := pts > 0
	_points_btn.texture = BTN_FILLED if has_points else BTN_EMPTY
	(_points_btn.material as ShaderMaterial).set_shader_parameter("is_unlocked", has_points)

func _build_children_map() -> void:
	for item in ALL_ITEMS:
		_children_map[item] = []
	for item in ALL_ITEMS:
		var dep: ProgressionItem = item.depends_on
		if dep != null and dep in _children_map:
			_children_map[dep].append(item)

func _find_root() -> ProgressionItem:
	for item: ProgressionItem in ALL_ITEMS:
		if item.depends_on == null:
			return item
	return ALL_ITEMS[0]

func _subtree_width(item: ProgressionItem) -> float:
	var children: Array = _children_map[item]
	if children.is_empty():
		return float(NODE_W)
	var total := 0.0
	for child: ProgressionItem in children:
		total += _subtree_width(child)
	total += H_GAP * (children.size() - 1)
	return maxf(float(NODE_W), total)

func _compute_layout(item: ProgressionItem, center_x: float, depth: int) -> void:
	_positions[item] = Vector2(center_x - NODE_W * 0.5, depth * (NODE_H + V_GAP))
	var children: Array = _children_map[item]
	if children.is_empty():
		return
	var total_w := 0.0
	for child: ProgressionItem in children:
		total_w += _subtree_width(child)
	total_w += H_GAP * (children.size() - 1)
	var cx := center_x - total_w * 0.5
	for child: ProgressionItem in children:
		var cw := _subtree_width(child)
		_compute_layout(child, cx + cw * 0.5, depth + 1)
		cx += cw + H_GAP

func _normalize_positions() -> void:
	var min_x := INF
	for pos: Vector2 in _positions.values():
		min_x = minf(min_x, pos.x)
	if min_x < 0.0:
		for item in _positions:
			_positions[item].x -= min_x

func _spawn_connectors(item: ProgressionItem) -> void:
	for child: ProgressionItem in _children_map[item]:
		_add_connector(item, child)
		_spawn_connectors(child)

func _add_connector(parent_item: ProgressionItem, child_item: ProgressionItem) -> void:
	var pp: Vector2 = _positions[parent_item]
	var cp: Vector2 = _positions[child_item]

	var from := Vector2(pp.x + NODE_W * 0.5, pp.y + NODE_H)
	var to   := Vector2(cp.x + NODE_W * 0.5, cp.y)
	var dx   := to.x - from.x

	var nine := NinePatchRect.new()

	if absf(dx) < 1.0:
		nine.texture = CONNECTOR_DOWN
		var w := float(CONNECTOR_DOWN.get_width())
		nine.position = Vector2(from.x - w * 0.5, from.y)
		nine.size = Vector2(w, to.y - from.y)
	elif dx < 0.0:
		nine.patch_margin_left = 48
		nine.patch_margin_right = 48
		nine.texture = CONNECTOR_LEFT
		nine.position = Vector2(to.x - 24, from.y)
		nine.size = Vector2(from.x - to.x + 48, to.y - from.y)
	else:
		nine.patch_margin_left = 48
		nine.patch_margin_right = 48
		nine.texture = CONNECTOR_RIGHT
		nine.position = Vector2(from.x - 24, from.y)
		nine.size = Vector2(dx + 48, to.y - from.y)

	_connectors[child_item] = nine
	_content.add_child(nine)

func _spawn_buttons() -> void:
	for item: ProgressionItem in ALL_ITEMS:
		var btn: Control = ITEM_BUTTON.instantiate()
		btn.position = _positions[item]
		_content.add_child(btn)
		btn.setup(item, _connectors.get(item))
		btn.item_selected.connect(_sidebar.on_item_selected)
