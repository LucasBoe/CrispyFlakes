extends Node2D

@export var icon : Texture
@export var price : int
@export var module_name : String
@export var describtion : String
@export var item_cost : int
@export var max_guests : int = 0
@export var seat_positions: Array[Vector2] = []
@export var brew_duration : float = 20.0
@export var brews_per_water : int = 1
@export var effect_interval : float = 10.0
@export var mood_boost : float = 0.1
@export var action_duration : float = 1.0
@export var requires_water_tower: bool = false
@export var required_infrastructure_layer: StringName = &""

@export var bought: bool = false

signal bought_changed_signal(module)

func _ready() -> void:
	visible = bought

func set_bought(value: bool) -> void:
	bought = value
	visible = value
	bought_changed_signal.emit(self)

func is_dependency_met(room: RoomBase = null) -> bool:
	var required_layer := _get_required_infrastructure_layer()
	if required_layer == &"":
		return true
	if room == null:
		room = _get_room_owner()
	if room == null or not is_instance_valid(Building.infrastructure):
		return false
	return Building.infrastructure.room_has_service(room, required_layer)

func get_unmet_dependency_text(room: RoomBase = null) -> String:
	var required_layer := _get_required_infrastructure_layer()
	if required_layer != &"":
		var dependency_name := _get_dependency_label(required_layer)
		if is_dependency_met(room):
			return "([color=#48D98E]uses %s[/color])" % dependency_name.to_lower()
		return "[color=#ff8f5a]requires %s[/color]" % dependency_name.to_lower()
	return ""

func get_dependency_button_text(room: RoomBase = null) -> String:
	var required_layer := _get_required_infrastructure_layer()
	if required_layer == &"":
		return "Needs Infrastructure"
	return "Needs %s" % _get_dependency_label(required_layer)

func _get_required_infrastructure_layer() -> StringName:
	if required_infrastructure_layer != &"":
		return required_infrastructure_layer
	return &"water" if requires_water_tower else &""

func _get_dependency_label(layer_name: StringName) -> String:
	match layer_name:
		&"water":
			return "Water Line"
		_:
			return "Infrastructure"

func _get_room_owner() -> RoomBase:
	var current: Node = self
	while current != null:
		if current is RoomBase:
			return current
		current = current.get_parent()
	return null
