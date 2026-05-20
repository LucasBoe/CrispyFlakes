extends RefCounted
class_name ProgressionTreeLayouter

var _items: Array = []
var _node_w: float
var _node_h: float
var _h_gap: float
var _v_gap: float

var children_map: Dictionary = {}
var positions: Dictionary = {}
var connectors: Dictionary = {}
var root: ProgressionItem = null
var roots: Array[ProgressionItem] = []

func _init(items: Array, node_w: float, node_h: float, h_gap: float, v_gap: float) -> void:
	_items = items
	_node_w = node_w
	_node_h = node_h
	_h_gap = h_gap
	_v_gap = v_gap

func build() -> void:
	children_map.clear()
	positions.clear()
	connectors.clear()
	root = null
	roots.clear()

	_build_children_map()
	roots = _find_roots()
	root = roots[0] if not roots.is_empty() else null
	if root == null:
		return

	_compute_forest_layout()
	_normalize_positions()

func spawn_connectors(content: Control, connector_down: Texture2D, connector_left: Texture2D, connector_right: Texture2D) -> void:
	connectors.clear()
	if roots.is_empty():
		return

	for tree_root in roots:
		_spawn_connectors(tree_root, content, connector_down, connector_left, connector_right)

func _build_children_map() -> void:
	for item: ProgressionItem in _items:
		children_map[item] = []

	for item: ProgressionItem in _items:
		var dependency: ProgressionItem = item.depends_on
		if dependency != null and dependency in children_map:
			children_map[dependency].append(item)

func _find_roots() -> Array[ProgressionItem]:
	var found_roots: Array[ProgressionItem] = []
	for item: ProgressionItem in _items:
		if item.depends_on == null:
			found_roots.append(item)

	if found_roots.is_empty() and not _items.is_empty():
		found_roots.append(_items[0])
	return found_roots

func _compute_forest_layout() -> void:
	var total_width := 0.0
	for tree_root in roots:
		total_width += _subtree_width(tree_root)
	total_width += _h_gap * max(0, roots.size() - 1)

	var current_x := total_width * -0.5
	for tree_root in roots:
		var tree_width := _subtree_width(tree_root)
		_compute_layout(tree_root, current_x + tree_width * 0.5, 0)
		current_x += tree_width + _h_gap

func _subtree_width(item: ProgressionItem) -> float:
	var children: Array = children_map[item]
	if children.is_empty():
		return _item_width(item)

	var total := 0.0
	for child: ProgressionItem in children:
		total += _subtree_width(child)
	total += _h_gap * (children.size() - 1)
	return maxf(_item_width(item), total)

func _compute_layout(item: ProgressionItem, center_x: float, depth: int) -> void:
	var item_width := _item_width(item)
	positions[item] = Vector2(center_x - item_width * 0.5, depth * (_node_h + _v_gap))

	var children: Array = children_map[item]
	if children.is_empty():
		return

	var total_w := 0.0
	for child: ProgressionItem in children:
		total_w += _subtree_width(child)
	total_w += _h_gap * (children.size() - 1)

	var child_x := center_x - total_w * 0.5
	for child: ProgressionItem in children:
		var child_w := _subtree_width(child)
		_compute_layout(child, child_x + child_w * 0.5, depth + 1)
		child_x += child_w + _h_gap

func _item_width(item: ProgressionItem) -> float:
	return ProgressionItemButton.get_visual_width(item)

func _normalize_positions() -> void:
	if positions.is_empty():
		return

	var min_x := INF
	for pos: Vector2 in positions.values():
		min_x = minf(min_x, pos.x)

	if min_x < 0.0:
		for item in positions:
			positions[item].x -= min_x

func _spawn_connectors(item: ProgressionItem, content: Control, connector_down: Texture2D, connector_left: Texture2D, connector_right: Texture2D) -> void:
	for child: ProgressionItem in children_map[item]:
		_add_connector(item, child, content, connector_down, connector_left, connector_right)
		_spawn_connectors(child, content, connector_down, connector_left, connector_right)

func _add_connector(parent_item: ProgressionItem, child_item: ProgressionItem, content: Control, connector_down: Texture2D, connector_left: Texture2D, connector_right: Texture2D) -> void:
	var parent_pos: Vector2 = positions[parent_item]
	var child_pos: Vector2 = positions[child_item]
	var parent_width := _item_width(parent_item)
	var child_width := _item_width(child_item)

	var from := Vector2(parent_pos.x + parent_width * 0.5, parent_pos.y + _node_h)
	var to := Vector2(child_pos.x + child_width * 0.5, child_pos.y)
	var dx := to.x - from.x

	var connector := NinePatchRect.new()

	if absf(dx) < 1.0:
		connector.texture = connector_down
		var width := float(connector_down.get_width())
		connector.position = Vector2(from.x - width * 0.5, from.y)
		connector.size = Vector2(width, to.y - from.y)
	elif dx < 0.0:
		connector.patch_margin_left = 48
		connector.patch_margin_right = 48
		connector.texture = connector_left
		connector.position = Vector2(to.x - 24, from.y)
		connector.size = Vector2(from.x - to.x + 48, to.y - from.y)
	else:
		connector.patch_margin_left = 48
		connector.patch_margin_right = 48
		connector.texture = connector_right
		connector.position = Vector2(from.x - 24, from.y)
		connector.size = Vector2(dx + 48, to.y - from.y)

	connectors[child_item] = connector
	content.add_child(connector)
