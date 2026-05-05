class_name BuildingInfrastructureStove
extends RefCounted

const STOVE_SCENE := preload("res://scenes/infrastructure/stove_infrastructure.tscn")

var _infra
var _tilemap: TileMapLayer
var _stove_root: Node2D = null
var _stove_instances: Dictionary = {}

func setup(infra: BuildingInfrastructure, tilemap: TileMapLayer) -> void:
	_infra = infra
	_tilemap = tilemap
	_ensure_root()

func can_place(data, origin: Vector2i) -> bool:
	for col in data.width:
		for row in data.height:
			var index := origin + Vector2i(col, row)
			if _infra.has_data_at(index, BuildingInfrastructure.STOVE_LAYER):
				return false
			var room := Building.get_room_from_index(index) as RoomBase
			if room == null:
				return false
	return true

func refresh_visuals() -> void:
	var stove_root := _ensure_root()
	var layer: Dictionary = _infra.get_layer(BuildingInfrastructure.STOVE_LAYER)

	for index in _stove_instances.keys():
		if layer.has(index):
			continue
		var stale = _stove_instances[index]
		if is_instance_valid(stale):
			stale.queue_free()
		_stove_instances.erase(index)

	for index in layer.keys():
		var stove = _stove_instances.get(index, null)
		if not is_instance_valid(stove):
			stove = STOVE_SCENE.instantiate()
			stove.setup(index, layer[index])
			stove_root.add_child(stove)
			_stove_instances[index] = stove
		else:
			stove.setup(index, layer[index])

func get_stove_at(index: Vector2i):
	return _stove_instances.get(index, null)

func get_all_stoves() -> Array:
	var stoves: Array = []
	for stove in _stove_instances.values():
		if is_instance_valid(stove):
			stoves.append(stove)
	return stoves

func get_stove_count() -> int:
	return _infra.get_layer(BuildingInfrastructure.STOVE_LAYER).size()

func _ensure_root() -> Node2D:
	if is_instance_valid(_stove_root):
		return _stove_root

	_stove_root = _infra.get_node_or_null("StoveVisuals") as Node2D
	if _stove_root == null:
		_stove_root = Node2D.new()
		_stove_root.name = "StoveVisuals"
		_stove_root.z_as_relative = true
		_stove_root.z_index = 1
		_infra.add_child(_stove_root)
	return _stove_root
